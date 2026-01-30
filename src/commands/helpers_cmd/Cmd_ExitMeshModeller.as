namespace automata { namespace Helpers { namespace ExitMeshModeller {

const uint OVL_ITEM = 2;
const uint OVL_MM   = 3;
const uint OVL_DLG  = 23;

const string IE_PROPS_ANCHOR = "0/4/1/0/0";
const string MM_BTN_EXIT     = "0/0/0/2/0";

const string DLG_BTN_YES     = "1/0/2/1/0/0";
const string DLG_BTN_NO      = "1/0/2/1/1/0";
const string DLG_BTN_CANCEL  = "1/0/2/1/2/0";

const string CTX_MM_PENDING_ACTIVE  = "mm.pending.active";
const string CTX_MM_PENDING_BLOCK   = "mm.pending.block";
const string CTX_MM_PENDING_VARIANT = "mm.pending.variant";
const string CTX_MM_PENDING_MODE    = "mm.pending.mode";
const string CTX_MM_PENDING_PREFER  = "mm.pending.prefer";

const string CTX_MM_OPEN_DEPTH      = "mmOpenDepth";

bool _IsItemEditorNow() {
    auto app = GetApp();
    return cast<CGameEditorItem>(app.Editor) !is null;
}

bool _IsMeshModellerNow() {
    auto app = GetApp();
    return cast<CGameEditorMesh>(app.Editor) !is null;
}

int _ArgInt(Json::Value@ a, const string &in key, int def) {
    if (a is null || !a.HasKey(key)) return def;
    try { return int(a[key]); } catch {}
    try {
        string s = string(a[key]).Trim();
        if (s.Length > 0) return Text::ParseInt(s);
    } catch {}
    try { return bool(a[key]) ? 1 : 0; } catch {}
    return def;
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

string _ArgStr(Json::Value@ a, const string &in key, const string &in def) {
    if (a is null || !a.HasKey(key)) return def;
    try { return string(a[key]); } catch {}
    return def;
}

string _ArgAction(Json::Value@ a, const string &in key, const string &in def) {
    string s = _ArgStr(a, key, def).ToLower().Trim();
    if (s == "yes" || s == "keep" || s == "save" || s == "y" || s == "ok") return "yes";
    if (s == "no"  || s == "discard" || s == "n") return "no";
    if (s == "cancel" || s == "esc" || s == "cn") return "cancel";
    return def;
}

int _CtxGetInt(FlowRun@ run, const string &in key, int def) {
    if (run is null) return def;
    string s;
    if (run.ctx.GetString(key, s)) {
        s = s.Trim();
        if (s.Length > 0) {
            try { return Text::ParseInt(s); } catch {}
        }
    }
    return def;
}

void _CtxSetInt(FlowRun@ run, const string &in key, int v) {
    if (run is null) return;
    run.ctx.Set(key, tostring(v));
}

bool _DialogVisible() {
    if (UiNav::ResolvePath(DLG_BTN_YES, OVL_DLG) !is null) return true;
    if (UiNav::ResolvePath(DLG_BTN_NO,  OVL_DLG) !is null) return true;
    if (UiNav::ResolvePath(DLG_BTN_CANCEL, OVL_DLG) !is null) return true;
    return false;
}

bool _ClickDialogAction(const string &in actIn) {
    string act = actIn.ToLower().Trim();
    string path = DLG_BTN_YES;
    if (act == "no" || act == "discard") path = DLG_BTN_NO;
    else if (act == "cancel")            path = DLG_BTN_CANCEL;
    return UiNav::ClickPath(path, OVL_DLG);
}

string _WaitForClosedOrDialog(int timeoutMs) {
    uint until = Time::Now + uint(Math::Max(0, timeoutMs));
    while (Time::Now < until) {
        if (!_IsMeshModellerNow()) return "closed";
        if (_DialogVisible()) return "dialog";
        yield();
    }
    return "timeout";
}

bool _WaitForAfterPath(uint ovl, const string &in path, int timeoutMs, bool requireIt) {
    if (path.Trim().Length == 0) return true;
    bool ok = UiNav::WaitForPath(path, ovl, timeoutMs, 33);
    if (!ok && requireIt) return false;
    if (!ok) {
        log("ExitMeshModeller: afterPath not detected: ovl=" + tostring(ovl) + " path=" + path, LogLevel::Warn, 116, "_WaitForAfterPath");

    }
    return true;
}

void _ClearPendingAndIntent(FlowRun@ run, const string &in cmdName, const string &in note) {
    
    if (run !is null) {
        string act = "";
        if (run.ctx.GetString(CTX_MM_PENDING_ACTIVE, act) && act == "1") {
            string blk = "";
            string v   = "";
            run.ctx.GetString(CTX_MM_PENDING_BLOCK, blk);
            run.ctx.GetString(CTX_MM_PENDING_VARIANT, v);

            if (blk.Length > 0 && v.Length > 0) {
                automata::Helpers::VariantSkips::MarkSafeRemove(blk, v, cmdName + " ok");
                
                automata::Helpers::VariantSkips::AutoVacuumIfNeeded(20000, 15000);
            }

            
            run.ctx.Set(CTX_MM_PENDING_ACTIVE,  "0");
            run.ctx.Set(CTX_MM_PENDING_BLOCK,   "");
            run.ctx.Set(CTX_MM_PENDING_VARIANT, "");
            run.ctx.Set(CTX_MM_PENDING_MODE,    "");
            run.ctx.Set(CTX_MM_PENDING_PREFER,  "");
        }
    }
    
    string msg = cmdName + ": mesh modeller closed.";
    if (note.Length > 0) msg += " " + note;
    automata::Helpers::CrashWatch::ClearIntent("cleared", msg);
}

bool _DoExit(FlowRun@ run, Json::Value@ args, const string &in cmdName, const string &in defaultAction) {
    string action     = _ArgAction(args, "action", defaultAction);
    int timeoutMs     = _ArgInt(args, "timeoutMs", 6000);

    int times = _ArgInt(args, "times", 1);
    if (times <= 0) times = _ArgInt(args, "repeat", 1);
    if (times <= 0) {
        int depth = _CtxGetInt(run, CTX_MM_OPEN_DEPTH, 0);
        times = depth > 0 ? depth : 1;
    }
    times = Math::Clamp(times, 1, 1000);

    bool waitAfter        = _ArgBool(args, "waitAfter", true);
    int afterOverlayI     = _ArgInt(args, "afterOverlay", int(OVL_ITEM));
    uint afterOverlay     = uint(Math::Max(0, afterOverlayI));
    string afterPath      = _ArgStr(args, "afterPath", IE_PROPS_ANCHOR);
    int afterTimeoutMs    = _ArgInt(args, "afterTimeoutMs", 4000);
    bool requireAfterPath = _ArgBool(args, "requireAfterPath", false);

    if (!_IsMeshModellerNow()) {
        _ClearPendingAndIntent(run, cmdName, "Already not in Mesh Modeller.");
        return true;
    }

    bool closedAtLeastOnce = false;

    for (int pass = 0; pass < times; ++pass) {
        if (!_IsMeshModellerNow()) break;

        bool clicked = UiNav::ClickPath(MM_BTN_EXIT, OVL_MM);
        if (!clicked) {
            if (!_IsMeshModellerNow() || _IsItemEditorNow()) break;
            if (run !is null) run.ctx.lastError = cmdName + ": Exit button not found/clickable.";
            return false;
        }

        string state = _WaitForClosedOrDialog(timeoutMs);

        if (state == "dialog") {
            if (!_ClickDialogAction(action)) {
                if (run !is null) run.ctx.lastError = cmdName + ": Dialog appeared but could not click '" + action + "'.";
                return false;
            }

            string st2 = _WaitForClosedOrDialog(timeoutMs);
            if (st2 == "timeout" && _IsMeshModellerNow()) {
                if (run !is null) run.ctx.lastError = cmdName + ": Timeout waiting for Mesh Modeller to close after dialog.";
                return false;
            }
        } else if (state == "timeout") {
            if (_IsMeshModellerNow()) {
                if (run !is null) run.ctx.lastError = cmdName + ": Timeout waiting for Mesh Modeller to close or dialog.";
                return false;
            }
        }

        if (!_IsMeshModellerNow()) {
            closedAtLeastOnce = true;

            int depth = _CtxGetInt(run, CTX_MM_OPEN_DEPTH, 0);
            if (depth > 0) _CtxSetInt(run, CTX_MM_OPEN_DEPTH, depth - 1);

            if (waitAfter && _IsItemEditorNow()) {
                bool okAfter = _WaitForAfterPath(afterOverlay, afterPath, afterTimeoutMs, requireAfterPath);
                if (!okAfter) {
                    if (run !is null) run.ctx.lastError = cmdName + ": afterPath required but not found.";
                    return false;
                }
            }
        }
    }

    if (_IsMeshModellerNow()) {
        if (run !is null) run.ctx.lastError = cmdName + ": Still in Mesh Modeller after " + tostring(times) + " attempt(s).";
        return false;
    }

    if (closedAtLeastOnce) _ClearPendingAndIntent(run, cmdName, "");
    else                   _ClearPendingAndIntent(run, cmdName, "Closed without detectable pass.");

    return true;
}

bool Cmd_ExitMeshModellerKeep(FlowRun@ run, Json::Value@ args) { return _DoExit(run, args, "exit_mesh_modeller_keep", "yes"); }
bool Cmd_ExitMeshModeller(FlowRun@ run, Json::Value@ args)     { return _DoExit(run, args, "exit_mesh_modeller",      "no");  }

void RegisterExitMeshModeller(CommandRegistry@ R) {
    R.Register("exit_mesh_modeller_keep", CommandFn(Cmd_ExitMeshModellerKeep));
    R.Register("exit_mesh_modeller",      CommandFn(Cmd_ExitMeshModeller));
}

}}}