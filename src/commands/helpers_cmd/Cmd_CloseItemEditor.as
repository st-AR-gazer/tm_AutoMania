namespace automata { namespace Helpers { namespace ItemEditorExit {

const uint   OVL_ITEM   = 2;
const uint   OVL_DLG    = 16;
const string BTN_EXIT   = "0/4/0/0/2/0";
const string DLG_BASE   = "1/0/2";
const string DLG_LABEL  = "1/0/2/0";
const string DLG_BTNS   = "1/0/2/1";   

bool _IsItemEditorOpen(CGameCtnApp@ app) {
    return cast<CGameEditorItem>(app.Editor) !is null;
}

bool _WaitItemEditorGone(int timeoutMs) {
    CGameCtnApp@ app = GetApp();
    uint until = Time::Now + uint(timeoutMs);
    while (Time::Now < until) {
        if (!_IsItemEditorOpen(app)) return true;
        yield(33);
    }
    return !_IsItemEditorOpen(app);
}

bool _WaitForDialogOrClose(bool &out dlgPresent, int timeoutMs) {
    CGameCtnApp@ app = GetApp();
    uint until = Time::Now + uint(timeoutMs);
    while (Time::Now < until) {
        if (UiNav::Exists(DLG_BASE, OVL_DLG)) { dlgPresent = true; return true; }
        if (!_IsItemEditorOpen(app))          { dlgPresent = false; return true; }
        yield(33);
    }
    
    if (UiNav::Exists(DLG_BASE, OVL_DLG)) { dlgPresent = true; return true; }
    dlgPresent = false;
    return !_IsItemEditorOpen(app);
}

int _ChoiceIndexFromAction(const string &in actionLower) {
    
    if (actionLower == "no")     return 1;
    if (actionLower == "cancel") return 2;
    return 0;
}

bool Cmd_CloseItemEditor(FlowRun@ run, Json::Value@ args) {
    string closeOnce;
    if (run.ctx.GetString("closeActionOnce", closeOnce) && closeOnce.Length > 0) {
        Json::Value@ a = args is null ? Json::Object() : args;
        a["action"] = closeOnce;        
        @args = @a;
        run.ctx.Set("closeActionOnce", ""); 
        log("close_item_editor: using one-shot close override: '" + closeOnce + "'", LogLevel::Info, 52, "Cmd_CloseItemEditor");
    }

    string action = Helpers::Args::ReadStr(args, "action", "yes");
    string actionLower = action.ToLower().Trim();
    if (actionLower != "yes" && actionLower != "no" && actionLower != "cancel") actionLower = "yes";

    int timeoutMs = Helpers::Args::ReadInt(args, "timeoutMs", 3000);
    bool verifyPrompt = Helpers::Args::ReadBool(args, "verifyPrompt", true);

    CGameCtnApp@ app = GetApp();
    if (!_IsItemEditorOpen(app)) {
        
        run.ctx.SetBool("itemEditorClosed", true);
        run.ctx.SetBool("closeDialogShown", false);
        run.ctx.Set("closeDialogChoice", "");
        log("close_item_editor: Item Editor not open — nothing to do.", LogLevel::Info, 68, "Cmd_CloseItemEditor");
        return true;
    }
    
    if (!UiNav::WaitForPath(BTN_EXIT, OVL_ITEM, 3000, 33)) {
        run.ctx.lastError = "close_item_editor: Exit button not found at overlay 2 (" + BTN_EXIT + ").";
        return false;
    }
    
    if (!UiNav::ClickPath(BTN_EXIT, OVL_ITEM)) {
        run.ctx.lastError = "close_item_editor: Failed to click the exit button.";
        return false;
    }

    bool dlg = false;
    _WaitForDialogOrClose(dlg, timeoutMs);

    if (!dlg) {
        
        bool closed = _WaitItemEditorGone(1000);
        run.ctx.SetBool("itemEditorClosed", closed);
        run.ctx.SetBool("closeDialogShown", false);
        run.ctx.Set("closeDialogChoice", "");
        log("close_item_editor: No unsaved dialog — closed=" + (closed ? "true" : "false"), LogLevel::Info, 91, "Cmd_CloseItemEditor");
        return true;
    }

    run.ctx.SetBool("closeDialogShown", true);
    
    if (verifyPrompt) {
        string lbl = UiNav::ReadText(UiNav::ResolvePath(DLG_LABEL, OVL_DLG));
        string ll  = lbl.ToLower();
        if (ll.IndexOf("not saved") < 0 && ll.IndexOf("save it or discard") < 0) {
            log("close_item_editor: overlay-16 dialog label didn't match expected 'unsaved' prompt. Proceeding anyway.", LogLevel::Warn, 101, "Cmd_CloseItemEditor");

        }
    }

    int choiceIdx = _ChoiceIndexFromAction(actionLower);
    string btnPath = DLG_BTNS + "/" + tostring(choiceIdx) + "/0";

    if (!UiNav::ClickPath(btnPath, OVL_DLG)) {
        run.ctx.lastError = "close_item_editor: Failed to click dialog button '" + actionLower + "' at " + btnPath;
        return false;
    }

    run.ctx.Set("closeDialogChoice", actionLower);

    bool closedOut = false;
    if (choiceIdx == 1 ) {
        closedOut = _WaitItemEditorGone(1500);
    } else if (choiceIdx == 2 ) {
        closedOut = false;
    } else {
        
        closedOut = _WaitItemEditorGone(300);
    }
    run.ctx.SetBool("itemEditorClosed", closedOut);

    log("close_item_editor: dialog handled -> choice=" + actionLower + " closed=" + (closedOut ? "true" : "false"), LogLevel::Info, 127, "Cmd_CloseItemEditor");

    return true;
}

void RegisterItemEditorExit(CommandRegistry@ R) {
    R.Register("close_item_editor", CommandFn(Cmd_CloseItemEditor));
}

}}}
