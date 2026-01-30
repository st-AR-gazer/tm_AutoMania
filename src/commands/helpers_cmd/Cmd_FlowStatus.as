namespace automata { namespace Helpers { namespace FlowStatus {

const int kSchemaVersion = 1;
const uint kTailEventsMax = 32;

const string kStatusFile = "flow.status.json";
const string kEventsFile = "flow.events.jsonl";

Json::Value@ gStatusDoc = null;
string gRunId = "";
dictionary gSeenDedupe; 

bool _ReadBoolArg(Json::Value@ args, const string &in key, bool defVal) {
    if (args is null || !args.HasKey(key)) return defVal;
    auto v = args[key];
    auto t = v.GetType();

    if (t == Json::Type::Boolean) return bool(v);
    if (t == Json::Type::String) {
        string s = string(v).ToLower().Trim();
        if (s == "true" || s == "1" || s == "yes" || s == "y" || s == "on")  return true;
        if (s == "false"|| s == "0" || s == "no"  || s == "n" || s == "off") return false;
        return defVal;
    }
    try { return int(v) != 0; } catch {}
    try { return float(v) != 0.0f; } catch {}
    return defVal;
}

int _ReadIntArg(Json::Value@ args, const string &in key, int defVal) {
    if (args is null || !args.HasKey(key)) return defVal;
    auto v = args[key];
    try { return int(v); } catch {}
    try { return Text::ParseInt(string(v).Trim()); } catch {}
    return defVal;
}

string _ReadStrArg(Json::Value@ args, const string &in key, const string &in defVal) {
    if (args is null || !args.HasKey(key)) return defVal;
    try { return string(args[key]); } catch {}
    return defVal;
}

string _LowerTrim(const string &in s) { return s.ToLower().Trim(); }
string _StatusPath() { return IO::FromStorageFolder(kStatusFile); }
string _EventsPath() { return IO::FromStorageFolder(kEventsFile); }

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

void _DeleteIfExists(const string &in absPath) {
    try {
        if (IO::FileExists(absPath)) IO::Delete(absPath);
    } catch {}
}

Json::Value@ _BuildCtxSnapshot(FlowRun@ run) {
    Json::Value@ o = Json::Object();
    if (run is null) return o;

    string blockName;
    if (run.ctx.GetString("blockName", blockName) && blockName.Length > 0) o["blockName"] = blockName;

    string invRel;
    if (run.ctx.GetString("inventoryRelDir", invRel) && invRel.Length > 0) o["inventoryRelDir"] = invRel;

    o["batchIndex"]   = run.ctx.batchIndex;
    
    if (run.ctx.kv.Exists("batchCount")) o["batchCount"] = int(run.ctx.kv["batchCount"]);
    o["loopActive"]   = run.ctx.loopActive;
    o["jumpToStep"]   = run.ctx.jumpToStep;

    return o;
}

string _FlowStatusToString(FlowRun@ run) {
    if (run is null) return "unknown";
    if (run.ctx.cancelled) return "cancelled";
    if (run.status == FlowStatus::Running) return "running";
    if (run.status == FlowStatus::Paused)  return "paused";
    if (run.status == FlowStatus::Done)    return "done";
    if (run.status == FlowStatus::Error)   return "error";
    if (run.status == FlowStatus::Idle)    return "idle";
    return "unknown";
}

void _EnsureDoc() {
    if (gStatusDoc is null) @gStatusDoc = Json::Object();
    if (!gStatusDoc.HasKey("schema")) gStatusDoc["schema"] = kSchemaVersion;
    if (!gStatusDoc.HasKey("run"))    gStatusDoc["run"] = Json::Object();
    if (!gStatusDoc.HasKey("counts")) gStatusDoc["counts"] = Json::Object();
    if (!gStatusDoc.HasKey("eventsTail")) gStatusDoc["eventsTail"] = Json::Array();

    Json::Value@ c = gStatusDoc["counts"];
    if (!c.HasKey("info"))  c["info"] = 0;
    if (!c.HasKey("warn"))  c["warn"] = 0;
    if (!c.HasKey("error")) c["error"] = 0;
}

void _WriteStatusNow() {
    _EnsureDoc();
    gStatusDoc["updatedAtMs"] = int(Time::Now);

    string json = Json::Write(gStatusDoc, false);

    bool ok = _WriteTextFile(_StatusPath(), json);
    if (!ok) log("FlowStatus: failed to write status file: " + _StatusPath(), LogLevel::Warn, 127, "_WriteStatusNow");
    
    try {
        string mirrorDir = IO::FromUserGameFolder("AutoMania/status");
        if (!IO::FolderExists(mirrorDir)) IO::CreateFolder(mirrorDir, true);

        string mirrorPath = IO::FromUserGameFolder("AutoMania/status/flow.status.json");
        _WriteTextFile(mirrorPath, json);
    } catch {
        
    }
}

void _IncCount(const string &in sevLower) {
    _EnsureDoc();
    Json::Value@ c = gStatusDoc["counts"];
    if (!c.HasKey(sevLower)) c[sevLower] = 0;
    int v = 0;
    try { v = int(c[sevLower]); } catch { v = 0; }
    c[sevLower] = v + 1;
}

void _PushTailEvent(Json::Value@ ev) {
    _EnsureDoc();
    Json::Value@ arr = gStatusDoc["eventsTail"];
    if (arr.GetType() != Json::Type::Array) { gStatusDoc["eventsTail"] = Json::Array(); @arr = gStatusDoc["eventsTail"]; }

    arr.Add(ev);

    while (arr.Length > kTailEventsMax) arr.Remove(0);
}


void BeginRun(FlowRun@ run) {
    gSeenDedupe.DeleteAll();
    gRunId = tostring(Time::Now);

    @gStatusDoc = Json::Object();
    _EnsureDoc();
    
    _DeleteIfExists(_EventsPath());

    Json::Value@ r = gStatusDoc["run"];
    r["runId"] = gRunId;
    r["flowName"] = run.flow.name;
    r["flowSourcePath"] = run.flow.sourcePath;
    r["startedAtMs"] = int(Time::Now);
    r["status"] = "running";
    r["statusStr"] = "Starting…";
    r["stepIndex"] = int(run.ctx.stepIndex);
    r["stepCount"] = int(run.flow.steps.Length);
    r["stepCmd"] = "";
    r["phase"] = "start";
    r["params"] = automata::JsonDeepClone(run.params);
    r["lastStepOk"] = -1;
    r["ctx"] = _BuildCtxSnapshot(run);

    run.ctx.Set("runId", gRunId);

    _WriteStatusNow();
    log("FlowStatus: begin run id=" + gRunId + " flow='" + run.flow.name + "'", LogLevel::Info, 187, "BeginRun");
}

void OnStepStart(FlowRun@ run, const string &in stepCmd) {
    _EnsureDoc();
    Json::Value@ r = gStatusDoc["run"];
    r["status"] = _FlowStatusToString(run);
    r["statusStr"] = run.statusStr;
    r["stepIndex"] = int(run.ctx.stepIndex);
    r["stepCount"] = int(run.flow.steps.Length);
    r["stepCmd"] = stepCmd;
    r["phase"] = "pre";
    r["ctx"] = _BuildCtxSnapshot(run);
    _WriteStatusNow();
}

void OnStepOk(FlowRun@ run, const string &in stepCmd) {
    _EnsureDoc();
    Json::Value@ r = gStatusDoc["run"];
    r["status"] = _FlowStatusToString(run);
    r["statusStr"] = run.statusStr;
    r["stepIndex"] = int(run.ctx.stepIndex);
    r["stepCount"] = int(run.flow.steps.Length);
    r["stepCmd"] = stepCmd;
    r["phase"] = "post";
    r["lastStepOk"] = int(run.ctx.stepIndex);
    r["ctx"] = _BuildCtxSnapshot(run);
    _WriteStatusNow();
}

void OnRunEnd(FlowRun@ run) {
    _EnsureDoc();
    Json::Value@ r = gStatusDoc["run"];
    r["status"] = _FlowStatusToString(run);
    r["statusStr"] = run.statusStr;
    r["phase"] = "end";
    r["ctx"] = _BuildCtxSnapshot(run);
    _WriteStatusNow();
}

void RecordEvent(FlowRun@ run,
                 const string &in severityIn,
                 const string &in codeIn,
                 const string &in messageIn,
                 Json::Value@ extra = null)
{
    string sev = _LowerTrim(severityIn);
    if (sev != "info" && sev != "warn" && sev != "error") sev = "warn";

    string code = codeIn.Trim();
    if (code.Length == 0) code = "event";

    string msg = messageIn;
    if (msg.Length == 0) msg = "(empty)";

    Json::Value@ ev = Json::Object();
    ev["tMs"] = int(Time::Now);
    ev["severity"] = sev;
    ev["code"] = code;
    ev["message"] = msg;

    if (run !is null) {
        ev["runId"] = gRunId;
        ev["flowName"] = run.flow.name;
        ev["stepIndex"] = int(run.ctx.stepIndex);
        ev["stepCmd"] = (run.ctx.stepIndex < run.flow.steps.Length) ? run.flow.steps[run.ctx.stepIndex].cmd : "";
        ev["ctx"] = _BuildCtxSnapshot(run);
    }

    if (extra !is null && extra.GetType() == Json::Type::Object) {
        ev["extra"] = extra;
    }

    bool okAppend = _AppendLine(_EventsPath(), Json::Write(ev, false));
    if (!okAppend) {
        log("FlowStatus: failed to append event to: " + _EventsPath(), LogLevel::Warn, 262, "RecordEvent");
    }
    
    _IncCount(sev);
    _PushTailEvent(ev);

    _EnsureDoc();
    gStatusDoc["lastEvent"] = ev;

    _WriteStatusNow();
}


bool Cmd_CheckForError(FlowRun@ run, Json::Value@ args) {
    int overlay = _ReadIntArg(args, "overlay", run.ctx.defaultOverlay);
    string path = _ReadStrArg(args, "path", "");
    if (path.Length == 0) {
        run.ctx.lastError = "check_for_error: missing args.path";
        return false;
    }

    string contains  = _ReadStrArg(args, "contains", "");
    string sev       = _ReadStrArg(args, "severity", "warn");
    string code      = _ReadStrArg(args, "code", "ui.check");
    string msg       = _ReadStrArg(args, "message", "");
    bool failOnFound = _ReadBoolArg(args, "failOnFound", false);
    bool dedupe      = _ReadBoolArg(args, "dedupe", true);
    
    CControlBase@ n = UiNav::ResolvePath(path, uint(overlay));
    if (n is null) {
        @n = UiNav::ResolvePathAnyRoot(path, uint(overlay), 24);
    }
    if (n is null) return true; 

    string uiText = UiNav::CleanUiFormatting(UiNav::ReadText(n));
    string uiLower = uiText.ToLower();
    bool match = true;

    if (contains.Length > 0) {
        match = (uiLower.IndexOf(contains.ToLower()) >= 0);
    }
    if (!match) return true;

    if (dedupe) {
        string blk = "";
        run.ctx.GetString("blockName", blk);
        string dk = code + "|" + blk;
        if (gSeenDedupe.Exists(dk)) return true;
        gSeenDedupe[dk] = "1";
    }

    Json::Value@ extra = Json::Object();
    extra["overlay"] = overlay;
    extra["path"] = path;
    extra["uiText"] = uiText;

    string outMsg = msg.Length > 0 ? msg : uiText;
    RecordEvent(run, sev, code, outMsg, extra);

    if (failOnFound) {
        run.ctx.lastError = "check_for_error matched (" + code + "): " + outMsg;
        return false;
    }
    return true;
}

bool Cmd_CheckMeshConvertWarning(FlowRun@ run, Json::Value@ args) {
    Json::Value@ a = Json::Object();
    a["overlay"] = 16;
    a["path"] = "1/0/2/1";
    a["contains"] = "couldn't be converted";
    a["severity"] = "warn";
    a["code"] = "mesh.convert.failed";
    return Cmd_CheckForError(run, a);
}

bool Cmd_StatusNote(FlowRun@ run, Json::Value@ args) {
    string sev  = _ReadStrArg(args, "severity", "info");
    string code = _ReadStrArg(args, "code", "note");
    string msg  = _ReadStrArg(args, "message", "");

    Json::Value@ extra = null;
    if (args !is null && args.HasKey("extra") && args["extra"].GetType() == Json::Type::Object) {
        @extra = args["extra"];
    }
    RecordEvent(run, sev, code, msg, extra);
    return true;
}

bool Cmd_TryExecute(FlowRun@ run, Json::Value@ args) {
    string innerCmd = _ReadStrArg(args, "cmd", "");
    if (innerCmd.Length == 0) {
        run.ctx.lastError = "try_execute: missing args.cmd";
        return false;
    }

    Json::Value@ innerArgs = Json::Object();
    if (args !is null && args.HasKey("args") && args["args"].GetType() == Json::Type::Object) {
        @innerArgs = args["args"];
    }

    string sev      = _ReadStrArg(args, "severity", "warn");
    string code     = _ReadStrArg(args, "code", "cmd.failed");
    string msgPref  = _ReadStrArg(args, "message", "");
    bool cont       = _ReadBoolArg(args, "continueOnFail", true);
    bool clearErr   = _ReadBoolArg(args, "clearLastError", true);

    string beforeErr = run.ctx.lastError;

    bool ok = automata::gCmds.Execute(innerCmd, run, innerArgs);

    run.ctx.Set("tryExecuteLastCmd", innerCmd);
    run.ctx.Set("tryExecuteLastOk", ok ? "1" : "0");

    if (ok) return true;

    string err = run.ctx.lastError;
    if (err.Length == 0) err = "(no ctx.lastError provided)";

    Json::Value@ extra = Json::Object();
    extra["innerCmd"] = innerCmd;
    extra["innerArgs"] = innerArgs;
    extra["innerError"] = err;

    string outMsg = msgPref.Length > 0 ? (msgPref + " | " + err) : (innerCmd + " failed: " + err);
    RecordEvent(run, sev, code, outMsg, extra);

    if (clearErr) run.ctx.lastError = beforeErr;

    return cont ? true : false;
}


void RegisterFlowStatusCommands(CommandRegistry@ R) {
    R.Register("check_for_error",             CommandFn(Cmd_CheckForError));
    R.Register("check_mesh_convert_warning",  CommandFn(Cmd_CheckMeshConvertWarning));
    R.Register("status_note",                CommandFn(Cmd_StatusNote));
    R.Register("try_execute",                CommandFn(Cmd_TryExecute));
}

}}}