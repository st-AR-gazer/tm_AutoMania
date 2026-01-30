namespace automata { namespace Helpers { namespace VariantSkips {

const string VSM_DB_FILE = "variants.skip.json";

uint gVsmDirtyOps = 0;
uint gVsmLastVacuumAt = 0;

string _VsmDbPath() {
    return IO::FromStorageFolder(VSM_DB_FILE);
}

bool _ArgBool(Json::Value@ a, const string &in key, bool def) {
    if (a is null || !a.HasKey(key)) return def;
    try { return bool(a[key]); } catch {}
    try { return int(a[key]) != 0; } catch {}
    try {
        string s = string(a[key]).ToLower().Trim();
        if (s == "true" || s == "1" || s == "yes" || s == "y" || s == "on")  return true;
        if (s == "false"|| s == "0" || s == "no"  || s == "n" || s == "off") return false;
    } catch {}
    return def;
}

string _VsmLower(const string &in s) { return s.ToLower().Trim(); }

bool _VsmReadAll(const string &in path, string &out text) {
    text = "";
    if (!IO::FileExists(path)) return false;
    IO::File f(path, IO::FileMode::Read);
    text = f.ReadToEnd();
    f.Close();
    return true;
}

bool _VsmWriteAll(const string &in path, const string &in text) {
    IO::File f(path, IO::FileMode::Write);
    f.Write(text);
    f.Close();
    return true;
}

int _VsmCountLines(const string &in s) {
    if (s.Length == 0) return 0;
    int n = 1;
    for (int i = 0; i < s.Length; ++i) {
        if (s.SubStr(i, 1) == "\n") n++;
    }
    return n;
}

string _VsmGetStr(const Json::Value@ j, const string &in key, const string &in defVal = "") {
    if (j is null || !j.HasKey(key)) return defVal;
    try { return string(j[key]); } catch {}
    return defVal;
}

bool _VsmTryParseLine(const string &in line,
                      string &out block,
                      string &out variant,
                      string &out stateOut)
{
    block = ""; variant = ""; stateOut = "";

    string t = line.Trim();
    if (t.Length == 0) return false;

    Json::Value@ j = null;
    try { @j = Json::Parse(t); } catch { return false; }
    if (j is null) return false;
    if (j.GetType() != Json::Type::Object) return false;

    block   = _VsmGetStr(j, "block", _VsmGetStr(j, "blockName", ""));
    variant = _VsmGetStr(j, "variant", _VsmGetStr(j, "variantKey", ""));

    string st = _VsmGetStr(j, "state", _VsmGetStr(j, "status", _VsmGetStr(j, "type", "")));
    st = st.ToLower().Trim();

    string note = _VsmGetStr(j, "note", _VsmGetStr(j, "reason", _VsmGetStr(j, "message", "")));
    string nl = note.ToLower();

    if (st.Length == 0) {
        if (nl.IndexOf("pending") >= 0) st = "pending";
        else if (nl.IndexOf("crash") >= 0) st = "crash";
        else if (nl.IndexOf("clear") >= 0 || nl.IndexOf("safe") >= 0) st = "clear";
    }

    stateOut = st;
    return block.Length > 0 && variant.Length > 0;
}

bool _VsmIsCrashLike(const string &in stateLower) {
    string s = stateLower.ToLower().Trim();
    return (s == "crash" || s == "pending" || s == "skip" || s == "bad");
}

bool _VsmIsClearLike(const string &in stateLower) {
    string s = stateLower.ToLower().Trim();
    return (s == "clear" || s == "cleared" || s == "safe" || s == "ok" || s == "done");
}

void MarkSafeRemove(const string &in blockCanon, const string &in variantKey, const string &in why = "safe") {
    if (blockCanon.Length == 0 || variantKey.Length == 0) return;

    ClearPending(blockCanon, variantKey);

    gVsmDirtyOps++;

    if ((gVsmDirtyOps % 250) == 1) {
        log("VariantSkips: MarkSafeRemove (dirtyOps=" + tostring(gVsmDirtyOps) + ") last='" + blockCanon + "' / '" + variantKey + "' (" + why + ")", LogLevel::Info, 109, "MarkSafeRemove");

    }
}

bool VacuumSkipDb(bool backup = true) {
    string path = _VsmDbPath();
    if (!IO::FileExists(path)) return true;

    string txt;
    if (!_VsmReadAll(path, txt)) return false;

    string trimmed = txt.Trim();
    if (trimmed.Length == 0) return true;

    int beforeLines = _VsmCountLines(txt);

    if (backup) {
        string bak = path + ".bak." + tostring(Time::Now);
        _VsmWriteAll(bak, txt);
    }

    array<string> lines = txt.Split("\n");

    array<string> unknownLines;

    dictionary lastLineByKey;
    dictionary lastStateByKey;

    for (uint i = 0; i < lines.Length; ++i) {
        string line = lines[i].Trim();
        if (line.Length == 0) continue;

        string b, v, st;
        if (!_VsmTryParseLine(line, b, v, st)) {
            unknownLines.InsertLast(line);
            continue;
        }

        string key = _VsmLower(b) + "|" + _VsmLower(v);
        lastLineByKey[key] = line;
        lastStateByKey[key] = st;
    }

    string outText = "";
    for (uint i = 0; i < unknownLines.Length; ++i) {
        outText += unknownLines[i] + "\n";
    }

    array<string> keys = lastLineByKey.GetKeys();
    int kept = 0;
    for (uint i = 0; i < keys.Length; ++i) {
        string k = keys[i];
        string st = lastStateByKey.Exists(k) ? string(lastStateByKey[k]) : "";
        bool keep = _VsmIsCrashLike(st) && !_VsmIsClearLike(st);
        if (!keep) continue;

        outText += string(lastLineByKey[k]) + "\n";
        kept++;
    }

    _VsmWriteAll(path, outText);

    int afterLines = _VsmCountLines(outText);
    log("VariantSkips: VacuumSkipDb done. beforeLines=" + tostring(beforeLines)
        + " afterLines=" + tostring(afterLines)
        + " kept=" + tostring(kept)
        + " unknownPreserved=" + tostring(unknownLines.Length), LogLevel::Info, 173, "VacuumSkipDb");





    return true;
}

void AutoVacuumIfNeeded(int maxLines = 20000, uint minIntervalMs = 15000) {
    if (gVsmDirtyOps == 0) return;

    uint now = Time::Now;
    if (gVsmLastVacuumAt != 0 && now - gVsmLastVacuumAt < minIntervalMs) return;

    string path = _VsmDbPath();
    if (!IO::FileExists(path)) { gVsmDirtyOps = 0; return; }

    string txt;
    if (!_VsmReadAll(path, txt)) return;

    int lines = _VsmCountLines(txt);

    if (lines < maxLines && gVsmDirtyOps < 500) return;

    bool ok = VacuumSkipDb(false);
    if (ok) {
        gVsmLastVacuumAt = now;
        gVsmDirtyOps = 0;
    }
}

bool Cmd_VariantSkipsCleanup(FlowRun@ run, Json::Value@ args) {
    bool purgeNonCrash = _ArgBool(args, "purgeNonCrash", true);
    bool minify        = _ArgBool(args, "minify", true);
    bool dryRun        = _ArgBool(args, "dryRun", false);

    int rmBlocks = 0, rmVars = 0, beforeB = 0, beforeV = 0, afterB = 0, afterV = 0;
    string summary;

    bool ok = CleanupNow(purgeNonCrash, minify, dryRun,
                         rmBlocks, rmVars, beforeB, beforeV, afterB, afterV, summary);

    if (!ok) {
        if (run !is null) run.ctx.lastError = "variant_skips_cleanup: failed. " + summary;
        return false;
    }

    log("variant_skips_cleanup: " + summary + " | file=" + GetDbPath(), LogLevel::Info, 221, "Cmd_VariantSkipsCleanup");


    if (run !is null) {
        run.ctx.Set("variantSkipsCleanupSummary", summary);
        run.ctx.Set("variantSkipsCleanupDbPath", GetDbPath());
    }

    return true;
}

void RegisterVariantSkipsMaintenance(CommandRegistry@ R) {
    R.Register("variant_skips_cleanup", CommandFn(Cmd_VariantSkipsCleanup));
}

}}}
