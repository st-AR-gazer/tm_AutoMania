namespace automata { namespace Helpers { namespace CrashWatch {

const int kSchemaVersion = 1;

const string kIntentRel   = "AutoMania/status/crash.intent.json";
const string kCrashLogRel = "AutoMania/data/crash.variants.jsonl";

const string kFlowStatusRelStorage = "flow.status.json";

bool gDidStartupScan = false;

bool   gDirsEnsured = false;
string gLastIntentKey = "";
uint   gLastIntentWriteMs = 0;

string _IntentAbs()         { return IO::FromUserGameFolder(kIntentRel); }
string _CrashLogAbs()       { return IO::FromUserGameFolder(kCrashLogRel); }
string _StatusAbsStorage()  { return IO::FromStorageFolder(kFlowStatusRelStorage); }

string _StatusAbsMirror()   { return IO::FromUserGameFolder("AutoMania/status/flow.status.json"); }

void _EnsureDirsOnce() {
    if (gDirsEnsured) return;

    string sdir = IO::FromUserGameFolder("AutoMania/status");
    if (!IO::FolderExists(sdir)) IO::CreateFolder(sdir, true);

    string ddir = IO::FromUserGameFolder("AutoMania/data");
    if (!IO::FolderExists(ddir)) IO::CreateFolder(ddir, true);

    gDirsEnsured = true;
}

bool _WriteTextFile(const string &in absPath, const string &in data) {
    try {
        IO::File f(absPath, IO::FileMode::Write);
        f.Write(data);
        f.Close();
        return true;
    } catch {
        return false;
    }
}

bool _AppendLine(const string &in absPath, const string &in line) {
    try {
        IO::FileMode mode = IO::FileExists(absPath) ? IO::FileMode::Append : IO::FileMode::Write;
        IO::File f(absPath, mode);
        f.Write(line + "\n");
        f.Close();
        return true;
    } catch {
        return false;
    }
}

string _ReadTextFile(const string &in absPath) {
    try { return _IO::File::ReadFileToEnd(absPath, false); } catch { return ""; }
}

Json::Value@ _ReadJson(const string &in absPath) {
    if (!IO::FileExists(absPath)) return null;
    string txt = _ReadTextFile(absPath);
    if (txt.Length == 0) return null;
    return Json::Parse(txt);
}

bool _WriteJson(const string &in absPath, Json::Value@ v, bool pretty = false) {
    return _WriteTextFile(absPath, Json::Write(v, pretty));
}

string _SafeLower(const string &in s) { return s.ToLower(); }

string _BuildIntentDedupeKey(FlowRun@ run,
                             const string &in cmd,
                             const string &in blockName,
                             const string &in variantKey)
{
    string runId = "";
    int stepIndex = -1;

    if (run !is null) {
        run.ctx.GetString("runId", runId);
        stepIndex = int(run.ctx.stepIndex);
    }

    return runId + "|" + tostring(stepIndex) + "|" + cmd + "|" + blockName + "|" + variantKey;
}

void WriteIntent(FlowRun@ run,
                 const string &in cmd,
                 const string &in blockName,
                 const string &in variantKey)
{
    _EnsureDirsOnce();

    string dk = _BuildIntentDedupeKey(run, cmd, blockName, variantKey);
    uint now = Time::Now;

    if (dk == gLastIntentKey && (now - gLastIntentWriteMs) < 250) {
        return;
    }
    gLastIntentKey = dk;
    gLastIntentWriteMs = now;

    Json::Value@ j = Json::Object();
    j["schema"] = kSchemaVersion;
    j["phase"] = "intent";
    j["tMs"] = int(now);

    j["cmd"] = cmd;
    j["blockName"] = blockName;
    j["variantKey"] = variantKey;

    if (run !is null) {
        string runId;
        if (run.ctx.GetString("runId", runId) && runId.Length > 0) j["runId"] = runId;
        j["flowName"]  = run.flow.name;
        j["stepIndex"] = int(run.ctx.stepIndex);
    }

    bool ok = _WriteJson(_IntentAbs(), j, false);
    if (!ok) log("CrashWatch: failed to write intent file.", LogLevel::Warn, 123, "WriteIntent");
}

void ClearIntent(const string &in phase = "cleared", const string &in note = "") {
    _EnsureDirsOnce();

    string p = _IntentAbs();
    if (!IO::FileExists(p)) {
        gLastIntentKey = "";
        gLastIntentWriteMs = 0;
        return;
    }

    Json::Value@ j = _ReadJson(p);
    if (j is null || j.GetType() != Json::Type::Object) @j = Json::Object();

    j["schema"] = kSchemaVersion;
    j["phase"] = phase;
    j["clearedAtMs"] = int(Time::Now);
    if (note.Length > 0) j["note"] = note;

    _WriteJson(p, j, false);

    gLastIntentKey = "";
    gLastIntentWriteMs = 0;
}


bool _PrevRunLooksUnfinished(Json::Value@ statusDoc) {
    if (statusDoc is null || statusDoc.GetType() != Json::Type::Object) return false;
    if (!statusDoc.HasKey("run") || statusDoc["run"].GetType() != Json::Type::Object) return false;

    Json::Value@ r = statusDoc["run"];
    string st = r.HasKey("status") ? string(r["status"]).ToLower() : "";
    string ph = r.HasKey("phase")  ? string(r["phase"]).ToLower()  : "";

    if (st == "crashed") return false;

    if ((st == "running" || st == "paused") && ph != "end") return true;
    return false;
}

void _MarkStatusCrashed(Json::Value@ statusDoc, const string &in msg) {
    if (statusDoc is null || statusDoc.GetType() != Json::Type::Object) return;
    if (!statusDoc.HasKey("run") || statusDoc["run"].GetType() != Json::Type::Object) return;

    Json::Value@ r = statusDoc["run"];
    r["status"]    = "crashed";
    r["statusStr"] = msg;
    r["phase"]     = "end";
    statusDoc["updatedAtMs"] = int(Time::Now);
}

void OnPluginStartupRecovery() {
    if (gDidStartupScan) return;
    gDidStartupScan = true;

    _EnsureDirsOnce();

    Json::Value@ intent = _ReadJson(_IntentAbs());
    if (intent is null || intent.GetType() != Json::Type::Object) return;

    string intentPhase = intent.HasKey("phase") ? string(intent["phase"]).ToLower() : "";
    string blk = intent.HasKey("blockName") ? string(intent["blockName"]) : "";
    string var = intent.HasKey("variantKey") ? string(intent["variantKey"]) : "";

    Json::Value@ st = _ReadJson(_StatusAbsStorage());
    if (st is null) {
        st = _ReadJson(_StatusAbsMirror());
    }

    bool statusUnfinished = _PrevRunLooksUnfinished(st);

    bool shouldRecover =
        (intentPhase == "intent")
        || (statusUnfinished && blk.Length > 0 && var.Length > 0 && intentPhase != "recorded");

    if (!shouldRecover) return;

    if (blk.Length == 0 || var.Length == 0) {
        intent["schema"] = kSchemaVersion;
        intent["phase"] = "invalid";
        intent["invalidAtMs"] = int(Time::Now);
        intent["note"] = "CrashWatch: recovery wanted but intent missing blockName/variantKey.";
        _WriteJson(_IntentAbs(), intent, false);

        log("CrashWatch: recovery wanted but intent missing blockName/variantKey. phase='"
            + intentPhase + "' statusUnfinished=" + tostring(statusUnfinished), LogLevel::Warn, 209, "OnPluginStartupRecovery");


        return;
    }

    bool added = automata::Helpers::VariantSkips::PromoteToCrash(
        blk, var,
        "Auto-confirmed crash while opening Mesh Modeller."
    );

    Json::Value@ ev = Json::Object();
    ev["schema"]     = kSchemaVersion;
    ev["tMs"]        = int(Time::Now);
    ev["blockName"]  = blk;
    ev["variantKey"] = var;
    ev["source"]     = "CrashWatch.startup";
    ev["addedSkip"]  = added;

    if (st !is null && st.GetType() == Json::Type::Object && st.HasKey("run")) {
        Json::Value@ r = st["run"];
        if (r.GetType() == Json::Type::Object) {
            if (r.HasKey("runId"))     ev["runId"]     = string(r["runId"]);
            if (r.HasKey("flowName"))  ev["flowName"]  = string(r["flowName"]);
            if (r.HasKey("stepIndex")) ev["stepIndex"] = int(r["stepIndex"]);
            if (r.HasKey("stepCmd"))   ev["stepCmd"]   = string(r["stepCmd"]);
        }
    }
    _AppendLine(_CrashLogAbs(), Json::Write(ev, false));

    intent["schema"] = kSchemaVersion;
    intent["phase"] = "recorded";
    intent["recordedAtMs"] = int(Time::Now);
    intent["recordedFromPhase"] = intentPhase;
    intent["recordedReason"] = (intentPhase == "intent" ? "phase-intent" : "status-unfinished-fallback");
    intent["addedSkip"] = added;
    _WriteJson(_IntentAbs(), intent, false);

    if (statusUnfinished) {
        _MarkStatusCrashed(st, "Previous run ended unexpectedly (CrashWatch recovery).");
        _WriteJson(_StatusAbsStorage(), st, false);
        _WriteJson(_StatusAbsMirror(), st, false);
    }

    log("CrashWatch: recovered previous run"
        + " | last intent: " + blk + " / " + var
        + (added ? " [added]" : " [already-known]")
        + " | statusUnfinished=" + tostring(statusUnfinished)
        + " | intentPhaseWas='" + intentPhase + "'", LogLevel::Info, 253, "OnPluginStartupRecovery");





}

}}}
