namespace automata {

bool _GetOverlay(Json::Value@ args, RunCtx &in ctx, int &out ov) {
    ov = ctx.defaultOverlay;
    if (args !is null && args.HasKey("overlay")) ov = int(args["overlay"]);
    return true;
}

uint _ChildrenLen(CControlBase@ node) {
    if (node is null) return 0;
    CControlFrame@ f = cast<CControlFrame>(node);
    if (f !is null) return f.Childs.Length;
    CControlListCard@ lc = cast<CControlListCard>(node);
    if (lc !is null) return lc.Childs.Length;
    return 0;
}

CControlBase@ _ChildAt(CControlBase@ node, uint idx) {
    if (node is null) return null;
    CControlFrame@ f = cast<CControlFrame>(node);
    if (f !is null) {
        if (idx < f.Childs.Length) return f.Childs[idx];
        return null;
    }
    CControlListCard@ lc = cast<CControlListCard>(node);
    if (lc !is null) {
        if (idx < lc.Childs.Length) return lc.Childs[idx];
        return null;
    }
    return null;
}

bool _MatchText(const string &in hay, const string &in needle, const string &in match, bool caseSensitive) {
    string H = caseSensitive ? hay : hay.ToLower();
    string N = caseSensitive ? needle : needle.ToLower();
    if (match == "contains")    return H.IndexOf(N) >= 0;
    if (match == "startsWith")  return H.StartsWith(N);
    if (match == "endsWith")    return H.EndsWith(N);
    return H == N;
}

bool _SubtreeHasLabelMatch(CControlBase@ node, const string &in needle, const string &in match, bool caseSensitive) {
    if (node is null) return false;

    CControlLabel@ lbl = cast<CControlLabel>(node);
    if (lbl !is null) {
        if (_MatchText(lbl.Label, needle, match, caseSensitive)) return true;
    }

    uint L = _ChildrenLen(node);
    for (uint i = 0; i < L; ++i) {
        CControlBase@ ch = _ChildAt(node, i);
        if (ch is null) continue;
        if (_SubtreeHasLabelMatch(ch, needle, match, caseSensitive)) return true;
    }
    return false;
}

bool Cmd_UiClick(FlowRun@ run, Json::Value@ args) {
    if (args is null || !args.HasKey("path")) { run.ctx.lastError = "ui_click: missing 'path'"; return false; }
    int ov; _GetOverlay(args, run.ctx, ov);
    string path = string(args["path"]);
    bool ok = UiNav::ClickPath(path, ov);
    if (!ok) { run.ctx.lastError = "ui_click: path not clickable: " + path; return false; }
    return true;
}

bool Cmd_UiSetText(FlowRun@ run, Json::Value@ args) {
    if (args is null || !args.HasKey("path") || !args.HasKey("text")) { run.ctx.lastError = "ui_set_text: needs 'path' and 'text'"; return false; }
    int ov; _GetOverlay(args, run.ctx, ov);
    string path = string(args["path"]);
    string text = string(args["text"]);
    bool ok = UiNav::SetTextPath(path, text, ov);
    if (!ok) { run.ctx.lastError = "ui_set_text failed at " + path; return false; }
    return true;
}

bool Cmd_UiWaitForPath(FlowRun@ run, Json::Value@ args) {
    if (args is null || !args.HasKey("path")) {
        run.ctx.lastError = "ui_wait_for_path: needs 'path'";
        return false;
    }

    int ov; _GetOverlay(args, run.ctx, ov);
    string path = string(args["path"]);

    int timeout = args.HasKey("timeoutMs") ? int(args["timeoutMs"]) : 4000;
    int poll    = args.HasKey("pollMs")    ? int(args["pollMs"])    : 33;

    bool needContains = false;
    string needle = "";
    string match  = "equals";
    bool caseSensitive = false;

    if (args.HasKey("contains_label")) {
        needle = string(args["contains_label"]);
        needContains = needle.Length > 0;
    } else if (args.HasKey("containsLabel")) {
        needle = string(args["containsLabel"]);
        needContains = needle.Length > 0;
    }

    if (args.HasKey("contains")) {
        auto t = args["contains"].GetType();
        if (t == Json::Type::String) {
            needle = string(args["contains"]);
            needContains = needle.Length > 0;
        } else if (t == Json::Type::Object) {
            Json::Value@ o = args["contains"];
            if (o.HasKey("label")) {
                needle = string(o["label"]);
                needContains = needle.Length > 0;
            }
            if (o.HasKey("match")) {
                match = string(o["match"]).ToLower();
                if (match != "equals" && match != "contains" && match != "startswith" && match != "endswith") {
                    match = "equals";
                }
            }
            if (o.HasKey("caseSensitive")) caseSensitive = bool(o["caseSensitive"]);
        }
    }

    uint until = Time::Now + uint(timeout);
    while (Time::Now < until) {
        CControlBase@ node = UiNav::ResolvePath(path, ov);
        if (node !is null) {
            if (!needContains) {
                return true;
            } else if (_SubtreeHasLabelMatch(node, needle, match, caseSensitive)) {
                return true;
            }
        }
        yield(poll);
    }

    if (!needContains) {
        run.ctx.lastError = "ui_wait_for_path timeout at " + path + " (overlay " + tostring(ov) + ")";
    } else {
        run.ctx.lastError = "ui_wait_for_path timeout at " + path + " (overlay " + tostring(ov)
                          + "); did not find label " + needle
                          + " with match=" + match + (caseSensitive ? " (case)" : " (nocase)");
    }
    return false;
}

bool Cmd_Sleep(FlowRun@ run, Json::Value@ args) {
    int ms = (args !is null && args.HasKey("ms")) ? int(args["ms"]) : 0;
    if (ms > 0) yield(ms);
    return true;
}

bool Cmd_PauseHuman(FlowRun@ run, Json::Value@ args) {
    string msg = (args !is null && args.HasKey("message")) ? string(args["message"]) : "Paused. Continue?";
    run.ctx.statusStr = msg;
    while (!run.ctx.stepGateOpen && !run.ctx.cancelled) yield(33);
    run.ctx.stepGateOpen = false;
    return !run.ctx.cancelled;
}

void RegisterUiCommands(CommandRegistry@ R) {
    R.Register("ui_click", CommandFn(Cmd_UiClick));
    R.Register("ui_set_text", CommandFn(Cmd_UiSetText));
    R.Register("ui_wait_for_path", CommandFn(Cmd_UiWaitForPath));
    R.Register("sleep", CommandFn(Cmd_Sleep));
    R.Register("pause_human", CommandFn(Cmd_PauseHuman));
}

}
