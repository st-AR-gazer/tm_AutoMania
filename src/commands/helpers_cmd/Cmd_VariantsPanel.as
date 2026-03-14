namespace automata { namespace Helpers { namespace VariantsPanel {

const uint OVL = 2;

const string PROP_BASE_CAND1 = "0/4/1/0/1";
const string PROP_BASE_CAND2 = "0/4/1/0/2";
const int    ROW_START       = 11;

string _ActiveBase = PROP_BASE_CAND1; 

class AddStableResult {
    int addClicks = 0;
    int uniqueGained = 0;
}

bool _IsUpperAlpha(const string &in ch) {
    return ch == ch.ToUpper() && ch != ch.ToLower();
}

void _SplitCamelWords(const string &in s, array<string> &words) {
    words.Resize(0);
    if (s.Length == 0) return;
    string cur;
    for (int i = 0; i < s.Length; ++i) {
        string ch = s.SubStr(i, 1);
        if (_IsUpperAlpha(ch) && cur.Length > 0) {
            words.InsertLast(cur);
            cur = ch;
        } else {
            cur += ch;
        }
    }
    if (cur.Length > 0) words.InsertLast(cur);
}

string _StripColorPrefix(const string &in sIn) {
    if (sIn.Length >= 4 && sIn.SubStr(0,1) == "$") return sIn.SubStr(4);
    return sIn;
}

string _ParseVariantKey(const string &in raw) {
    string s = _StripColorPrefix(raw).Trim();
    int k = s.IndexOf(" (");
    if (k < 0) k = s.IndexOf(" ");
    if (k > 0) s = s.SubStr(0, k);
    return s.Trim();
}

bool _IsBrokenVariantKey(const string &in key) {
    string k = key.Trim();
    if (k.Length == 0) return true;
    if (k == "?-?-?") return true;
    return k.IndexOf("?") >= 0;
}

string _RowPath(const string &in basePath, int uiRow) {
    return basePath + "/" + tostring(uiRow);
}

string _RowLabelPath(const string &in basePath, int uiRow) {
    return basePath + "/" + tostring(uiRow) + "/6/4";
}

string _RowDeletePath(const string &in basePath, int uiRow) { 
    return basePath + "/" + tostring(uiRow) + "/2";
}

string _AddButtonPath(const string &in basePath) {
    return basePath + "/10/2";
}

string _ReadRowKeyText(const string &in basePath, int uiRow) {
    string path = _RowLabelPath(basePath, uiRow);
    string t = UiNav::ReadText(UiNav::ResolvePath(path, OVL));
    return t.Length > 0 ? _ParseVariantKey(t) : "";
}

bool _ScanRowsAtBase(const string &in basePath, array<int> &uiRows, array<string> &keys) {
    uiRows.Resize(0); keys.Resize(0);
    bool started = false;
    for (int r = ROW_START; r < ROW_START + 500; ++r) {
        CControlBase@ row = UiNav::ResolvePath(_RowPath(basePath, r), OVL);
        if (row is null) {
            if (started) break;
            continue;
        }
        started = true;
        string key = _ReadRowKeyText(basePath, r);
        if (key.Length == 0) continue;
        uiRows.InsertLast(r);
        keys.InsertLast(key);
    }
    return uiRows.Length > 0;
}

void _DetermineActiveBase() {
    array<int> r1; array<string> k1;
    array<int> r2; array<string> k2;

    bool has1 = _ScanRowsAtBase(PROP_BASE_CAND1, r1, k1);
    bool has2 = _ScanRowsAtBase(PROP_BASE_CAND2, r2, k2);

    
    if (has1 && !has2) _ActiveBase = PROP_BASE_CAND1;
    else if (!has1 && has2) _ActiveBase = PROP_BASE_CAND2;
    else if (has1 && has2) _ActiveBase = (r2.Length > r1.Length ? PROP_BASE_CAND2 : PROP_BASE_CAND1);
    else _ActiveBase = PROP_BASE_CAND1;

    log("VariantsPanel: ActiveBase=" + _ActiveBase, LogLevel::Info, 109, "_DetermineActiveBase");
}

bool _ClickAdd(const string &in basePath) {
    return UiNav::ClickPath(_AddButtonPath(basePath), OVL);
}

int _DeduplicateRows(const string &in basePath, int maxDeletes = 1024) {
    int deleted = 0;
    for (int guard = 0; guard < maxDeletes; ++guard) {
        array<int> rows; array<string> keys;
        _ScanRowsAtBase(basePath, rows, keys);
        if (rows.Length <= 1) break;

        dictionary firstIndex;   
        int dupRowUi = -1;

        for (int i = 0; i < int(rows.Length); ++i) {
            string key = keys[i];
            if (key.Length == 0) continue;
            if (!firstIndex.Exists(key)) {
                firstIndex[key] = i;
            } else {
                dupRowUi = rows[i];
                break;
            }
        }

        if (dupRowUi < 0) break; 

        string delPath = _RowDeletePath(basePath, dupRowUi);
        if (UiNav::ClickPath(delPath, OVL)) {
            deleted++;
            for (int f = 0; f < 2; ++f) yield();
            continue; 
        } else {
            
            log("variants_add_unique_rows: delete click failed at row ui=" + tostring(dupRowUi) + " path=" + delPath, LogLevel::Warn, 146, "_DeduplicateRows");

            break;
        }
    }
    return deleted;
}

AddStableResult _AddUntilStable(const string &in basePath, int maxAddClicks, int stabilizeTries,
                                int settleFrames, int maxTotalRows)
{
    AddStableResult r;

    array<int> rows; array<string> keys;
    _ScanRowsAtBase(basePath, rows, keys);

    dictionary seen;
    for (int i = 0; i < int(keys.Length); ++i) seen[keys[i]] = true;

    
    if (keys.Length == 0 && maxAddClicks > 0) {
        if (_ClickAdd(basePath)) {
            r.addClicks++;
            for (int f = 0; f < settleFrames; ++f) yield();
            _ScanRowsAtBase(basePath, rows, keys);
            for (int i = 0; i < int(keys.Length); ++i) {
                if (!seen.Exists(keys[i])) { seen[keys[i]] = true; r.uniqueGained++; }
            }
        }
    }

    int stable = 0;
    for (int i = 0; i < maxAddClicks; ++i) {
        if (int(rows.Length) >= maxTotalRows) break;

        bool clicked = _ClickAdd(basePath);
        if (clicked) r.addClicks++;
        for (int f = 0; f < settleFrames; ++f) yield();

        _DeduplicateRows(basePath, 8);

        array<int> rows2; array<string> keys2;
        _ScanRowsAtBase(basePath, rows2, keys2);

        int newUnique = 0;
        for (int k = 0; k < int(keys2.Length); ++k) {
            string kk = keys2[k];
            if (!seen.Exists(kk)) { seen[kk] = true; newUnique++; }
        }
        r.uniqueGained += newUnique;

        bool changed = clicked || newUnique > 0 || int(rows2.Length) > int(rows.Length);
        rows = rows2; keys = keys2;

        if (changed) {
            stable = 0;
        } else {
            stable++;
            if (stable >= stabilizeTries) break;
        }
    }

    _DeduplicateRows(basePath, 128);

    return r;
}

string _GetCanonicalFromCtxOrBlockIndex(FlowRun@ run) {
    string fromCtx = "";
    if (run.ctx.kv.Exists("blockName")) {
        try { fromCtx = string(run.ctx.kv["blockName"]); } catch {}
    }
    if (fromCtx.Length == 0) return "";

    CGameCtnBlockInfo@ info; string canonical; string err;
    if (automata::Helpers::Blocks::TryFindBlockInfoByName(fromCtx, info, canonical, err)) {
        if (canonical.Length > 0) return canonical;
    }
    return fromCtx;
}

string _BuildInventorySubpath(const string &in canonical, const string &in env, bool includeInventoryPath) {
    array<string> parts;
    if (includeInventoryPath) {
        array<string> tokens; _SplitCamelWords(canonical, tokens);
        string sub = automata::Helpers::SaveFile::JoinWithSlash(tokens); 
        if (sub.Length > 0) {
            parts.InsertLast(env);
            parts.InsertLast(sub);
            parts.InsertLast(canonical);
        } else {
            parts.InsertLast(env);
            parts.InsertLast(canonical);
        }
    } else {
        parts.InsertLast(env);
        parts.InsertLast(canonical);
    }
    return automata::Helpers::SaveFile::JoinWithSlash(parts);
}

string _ComputeSaveLocation(FlowRun@ run, Json::Value@ args) {
    string explicitPath = Helpers::Args::ReadStr(args, "saveLocation", "");
    if (explicitPath.Length > 0) return explicitPath;

    string root = Helpers::Args::ReadStr(args, "saveRoot", "Nadeo");
    string env  = Helpers::Args::ReadStr(args, "saveEnv",  "Stadium");
    string ext  = Helpers::Args::ReadStr(args, "saveExt",  ".Item.Gbx");
    bool useInv = Helpers::Args::ReadBool(args, "saveUseInventoryPath", true);

    string canonical = _GetCanonicalFromCtxOrBlockIndex(run);
    if (canonical.Length == 0) canonical = "UnknownBlock";

    string sub  = _BuildInventorySubpath(canonical, env, useInv); 
    string path = root;
    if (path.Length > 0) path += "/";
    path += sub;
    if (ext.Length > 0 && !path.ToLower().EndsWith(ext.ToLower())) path += ext;

    Json::Value@ j = Json::Object(); j["computedSaveLocation"] = path; j["canonical"] = canonical; j["env"] = env;
    if (run.ctx.kv.Exists("variantSaveDebug")) run.ctx.kv.Delete("variantSaveDebug");
    run.ctx.kv["variantSaveDebug"] = @j;

    return path;
}

bool _IsItemEditorOpen() {
    CGameCtnApp@ app = GetApp();
    return cast<CGameEditorItem>(app.Editor) !is null;
}

bool _WaitForItemEditorUI(const string &in basePath, int timeoutMs) {
    int until = Time::Now + timeoutMs;
    while (Time::Now < until) {
        if (_IsItemEditorOpen() && UiNav::ResolvePath(basePath, OVL) !is null) return true;
        yield(2);
    }
    return _IsItemEditorOpen(); 
}

bool _TryExitMeshOnce(FlowRun@ run) {
    Json::Value@ noArgs = Json::Object();
    bool ok = automata::gCmds.Execute("exit_mesh_modeller_keep", run, noArgs);
    if (!ok) ok = automata::gCmds.Execute("exit_mesh_modeller", run, noArgs);
    return ok;
}

bool _EnsureBackToItemEditor(FlowRun@ run, const string &in basePath, int maxAttempts, int waitPerAttemptMs) {
    for (int i = 0; i < maxAttempts; ++i) {
        if (_IsItemEditorOpen()) {
            if (_WaitForItemEditorUI(basePath, waitPerAttemptMs)) return true;
        }
        _TryExitMeshOnce(run);
        if (_WaitForItemEditorUI(basePath, waitPerAttemptMs)) return true;
    }
    return _IsItemEditorOpen();
}

bool Cmd_VariantsAddUniqueRows(FlowRun@ run, Json::Value@ args) {
    if (!_IsItemEditorOpen()) {
        run.ctx.lastError = "variants_add_unique_rows: Item Editor is not open.";
        return false;
    }
    
    if (!UiNav::WaitForPath(PROP_BASE_CAND1, OVL, 2000, 33) &&
        !UiNav::WaitForPath(PROP_BASE_CAND2, OVL, 2000, 33))
    {
        run.ctx.lastError = "variants_add_unique_rows: Properties UI not found on overlay 2.";
        return false;
    }

    _DetermineActiveBase();
    string basePath = _ActiveBase;

    int  maxAdd       = Helpers::Args::ReadIntClamped(args, "maxAddClicks",   64, 0, 1024);
    int  stabilizeTr  = Helpers::Args::ReadIntClamped(args, "stabilizeTries",  3, 1, 10);
    int  maxTotalRows = Helpers::Args::ReadIntClamped(args, "maxTotalRows",  256, 8, 4096);
    bool dedupe       = Helpers::Args::ReadBool(args, "dedupe", true);

    AddStableResult res = _AddUntilStable(basePath, maxAdd, stabilizeTr, 3, maxTotalRows);
    int addClicks = res.addClicks;
    int uniqGain  = res.uniqueGained;

    int deleted = 0;
    if (dedupe) deleted = _DeduplicateRows(basePath, 1024);
    
    array<int> rows; array<string> keys;
    _ScanRowsAtBase(basePath, rows, keys);

    Json::Value@ arr = Json::Array();
    for (int i = 0; i < int(keys.Length); ++i) arr.Add(keys[i]);

    run.ctx.SetInt("variantRowCount",    int(rows.Length));
    run.ctx.SetInt("variantAddedCount",  addClicks);
    run.ctx.SetInt("variantDeletedDups", deleted);

    if (run.ctx.kv.Exists("variantKeys"))      run.ctx.kv.Delete("variantKeys");
    if (run.ctx.kv.Exists("variantKeysArray")) run.ctx.kv.Delete("variantKeysArray");
    run.ctx.kv["variantKeys"]      = @arr;   
    run.ctx.kv["variantKeysArray"] = @keys;  

    log("variants_add_unique_rows: rows=" + tostring(rows.Length)
        + " addClicks=" + tostring(addClicks)
        + " uniqueGained=" + tostring(uniqGain)
        + " deletedDups=" + tostring(deleted)
        + " base=" + basePath, LogLevel::Info, 347, "Cmd_VariantsAddUniqueRows");










    return true;
}

bool Cmd_VariantsVisitAll(FlowRun@ run, Json::Value@ args) {
    if (!_IsItemEditorOpen()) {
        run.ctx.lastError = "variants_visit_all: Item Editor is not open.";
        return false;
    }

    _DetermineActiveBase();
    string basePath = _ActiveBase;

    string mode        = Helpers::Args::ReadStr(args, "mode", "block-to-block");
    int openDelay      = Helpers::Args::ReadIntClamped(args, "openDelayFrames", 1, 0, 60);
    int exitDelay      = Helpers::Args::ReadIntClamped(args, "exitDelayFrames", 0, 0, 60);
    int maxExitPerOpen = Helpers::Args::ReadIntClamped(args, "maxExitAttemptsPerVariant", 6, 1, 50);
    bool closeAfter    = Helpers::Args::ReadBool(args, "closeAllAfterLoop", true);
    bool skipBroken    = Helpers::Args::ReadBool(args, "skipBrokenVariants", false);
    bool saveAfter     = Helpers::Args::ReadBool(args, "saveAfter", false);
    string saveScope   = Helpers::Args::ReadStr(args, "saveScope", "item_editor");
    string endString   = Helpers::Args::ReadStr(args, "saveEndString", "");

    array<int> rows; array<string> keys;
    _ScanRowsAtBase(basePath, rows, keys);
    int count = int(rows.Length);
    if (count <= 0) {
        log("variants_visit_all: no variant rows to visit.", LogLevel::Info, 384, "Cmd_VariantsVisitAll");
        
        if (saveAfter) {
            string saveLoc0 = _ComputeSaveLocation(run, args);
            Json::Value@ sa0 = Json::Object();
            sa0["scope"]      = saveScope;
            sa0["from"]       = saveScope;
            sa0["dest"]       = saveLoc0;
            sa0["path"]       = saveLoc0;
            sa0["location"]   = saveLoc0;
            sa0["ensureDirs"] = true;
            if (endString.Length > 0) sa0["endString"] = endString;
            bool s0 = automata::gCmds.Execute("save_file", run, sa0);
            log("variants_visit_all: save_after(no-rows) -> " + (s0 ? "OK" : "FAILED"), s0 ? LogLevel::Info : LogLevel::Warn, 397, "Cmd_VariantsVisitAll");
        }
        return true;
    }

    int visited = 0;
    int skippedBroken = 0;
    
    for (int i = 0; i < count; ++i) {
        if (skipBroken) {
            string k = keys.Length > i ? keys[i] : "";
            if (_IsBrokenVariantKey(k)) {
                skippedBroken++;
                log("variants_visit_all: skipping broken variant '" + k + "' (index " + tostring(i) + ")", LogLevel::Info, 410, "Cmd_VariantsVisitAll");
                continue;
            }
        }

        Json::Value@ oa = Json::Object();
        oa["mode"]         = mode;
        oa["variantIndex"] = i;
        oa["prefer"]       = "auto";

        if (!automata::Helpers::OpenMeshModeller::Cmd_OpenMeshModeller(run, oa)) {
            log("variants_visit_all: failed to open mesh modeller for variant #" + tostring(i), LogLevel::Warn, 421, "Cmd_VariantsVisitAll");
            continue;
        }

        visited++;

        yield(openDelay);
        
        bool back = _EnsureBackToItemEditor(run, basePath, maxExitPerOpen, 500);
        if (!back) {
            log("variants_visit_all: could not return to Item Editor after variant #" + tostring(i) + " — attempting to continue", LogLevel::Warn, 431, "Cmd_VariantsVisitAll");
        }

        yield(exitDelay);
    }
    
    if (closeAfter) {
        bool backAll = _EnsureBackToItemEditor(run, basePath, Math::Max(10, count * 2), 500);
        if (!backAll) {
            log("variants_visit_all: WARNING — final ensure-back did not confirm Item Editor UI.", LogLevel::Warn, 440, "Cmd_VariantsVisitAll");
        }
    }

    int deletedAfter = _DeduplicateRows(basePath, 1024);
    if (deletedAfter > 0) {
        log("variants_visit_all: post-visit dedupe removed " + tostring(deletedAfter) + " row(s).", LogLevel::Info, 446, "Cmd_VariantsVisitAll");
    }
    
    if (saveAfter) {
        string saveLoc = _ComputeSaveLocation(run, args);
        Json::Value@ sa = Json::Object();
        sa["scope"]      = saveScope;
        sa["from"]       = saveScope;
        sa["dest"]       = saveLoc;
        sa["path"]       = saveLoc;
        sa["location"]   = saveLoc;
        sa["ensureDirs"] = true;
        if (endString.Length > 0) sa["endString"] = endString;

        bool saved = automata::gCmds.Execute("save_file", run, sa);
        log("variants_visit_all: save_after -> " + (saved ? "OK" : "FAILED"), saved ? LogLevel::Info : LogLevel::Warn, 461, "Cmd_VariantsVisitAll");
    }

    string extra = "";
    if (skipBroken) extra = " (skippedBroken=" + tostring(skippedBroken) + ")";
    log("variants_visit_all: visited " + tostring(visited) + " variant(s)" + extra + ".", LogLevel::Info, 466, "Cmd_VariantsVisitAll");
    return true;
}

void RegisterVariantsCommands(CommandRegistry@ R) {
    R.Register("variants_add_unique_rows", CommandFn(Cmd_VariantsAddUniqueRows));
    R.Register("variants_visit_all",       CommandFn(Cmd_VariantsVisitAll));
}

}}}
