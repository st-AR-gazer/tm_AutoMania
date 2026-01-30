namespace automata { namespace Helpers { namespace IconRotationApply {

const uint kOverlayItemEditor = 2;
const uint kOverlayDialog     = 14;

const string kIconButtonsBase = "0/4/1/0/1/6/5";
const string kBtnEditPath     = kIconButtonsBase + "/0"; 
const string kBtnNewPath      = kIconButtonsBase + "/3"; 

const string kDialogRoot      = "0/0";
const string kDialogGrid      = kDialogRoot + "/2";
const string kDialogTitleLbl  = kDialogRoot + "/3/1";

int _ToQuarter(const string &in s) {
    if (s.Length == 0) return 1;
    int v = 1; try { v = Text::ParseInt(s); } catch { v = 1; }
    if (v < 1 || v > 4) return 1;
    return v;
}

bool _WaitForIconButtons(string &out err) {
    if (!UiNav::WaitForPath(kIconButtonsBase, kOverlayItemEditor, 3000, 33)) {
        err = "Item Editor icon UI not found (overlay 2, path: " + kIconButtonsBase + ")";
        return false;
    }
    return true;
}

bool _ShouldClickEdit() {
    CControlBase@ nb = UiNav::ResolvePath(kBtnNewPath, kOverlayItemEditor);
    if (nb is null) return true; 
    CControlButton@ newBtn = cast<CControlButton>(nb);
    if (newBtn is null) return true;
    return newBtn.IsHiddenExternal; 
}

bool _WaitDialogTitle() {
    if (!UiNav::WaitForPath(kDialogTitleLbl, kOverlayDialog, 3000, 33)) return false;
    CControlBase@ lbl = UiNav::ResolvePath(kDialogTitleLbl, kOverlayDialog);
    if (lbl is null) return false;
    string t = UiNav::ReadText(lbl).ToLower();
    return t.IndexOf("icon") >= 0; 
}

int _RowForQuarter(int q) {
    switch (q) {
        case 1: return 1; 
        case 2: return 2; 
        case 3: return 3; 
        case 4: default: return 4; 
    }
}

bool _ClickQuarterRow(int row, string &out err) {
    if (!UiNav::WaitForPath(kDialogGrid, kOverlayDialog, 1500, 33)) {
        err = "Icon chooser grid not found at: " + kDialogGrid;
        return false;
    }

    string path = kDialogGrid + "/" + tostring(row) + "/0"; 
    if (UiNav::ClickPath(path, kOverlayDialog)) return true;
    
    string alt = path + "/0";
    if (UiNav::ClickPath(alt, kOverlayDialog)) return true;

    err = "Failed to click dialog path: " + path + " (and alt: " + alt + ")";
    return false;
}

bool _TryReadQuarterFromItemEditor(int &out quarter, string &out blockName) {
    CGameCtnApp@ app = GetApp();
    if (app is null) return false;
    CGameEditorItem@ editor = cast<CGameEditorItem>(app.Editor);
    if (editor is null) return false;
    CGameItemModel@ im = editor.ItemModel;
    if (im is null) return false;

    CGameCtnBlockInfoClassic@ bic = cast<CGameCtnBlockInfoClassic>(im.EntityModel);
    if (bic !is null) { quarter = int(bic.IconQuarterRotationY); blockName = bic.Name; return true; }

    CGameCtnBlockInfo@ bi = cast<CGameCtnBlockInfo>(im.EntityModel);
    if (bi !is null) { quarter = int(bi.IconQuarterRotationY); blockName = bi.Name; return true; }

    return false;
}

bool Cmd_ApplySavedIconRotation(FlowRun@ run, Json::Value@ args) {
    
    string rotStr;
    bool have = run.ctx.GetString("savedIconQuarterRotationY", rotStr) && rotStr.Length > 0;

    if (!have) {
        CGameCtnBlockInfo@ cur; string curName;
        if (Helpers::Blocks::GetCurrent(cur, curName) && cur !is null) {
            rotStr = tostring(cur.IconQuarterRotationY);
            have = true;
            log("apply_saved_icon_rotation: fallback to cached block rotation: " + rotStr, LogLevel::Info, 97, "Cmd_ApplySavedIconRotation");

        }
    }
    if (!have) {
        int q0; string nm0;
        if (_TryReadQuarterFromItemEditor(q0, nm0)) {
            rotStr = tostring(q0);
            have = true;
            log("apply_saved_icon_rotation: fallback to Item Editor rotation from '" + nm0 + "': " + rotStr, LogLevel::Info, 106, "Cmd_ApplySavedIconRotation");

        }
    }
    if (!have) {
        run.ctx.lastError = "apply_saved_icon_rotation: no savedIconQuarterRotationY in ctx, and no cached/live block.";
        return false;
    }

    int q   = _ToQuarter(rotStr);
    int row = _RowForQuarter(q);

    string err;
    if (!_WaitForIconButtons(err)) { run.ctx.lastError = err; return false; }

    string toClick = _ShouldClickEdit() ? kBtnEditPath : kBtnNewPath;
    if (!UiNav::ClickPath(toClick, kOverlayItemEditor)) {
        run.ctx.lastError = "Failed to click " + (toClick == kBtnEditPath ? "Edit" : "New") + " icon button at: " + toClick;
        return false;
    }
    
    if (!_WaitDialogTitle()) {
        run.ctx.lastError = "Icon chooser dialog did not appear on overlay 14 at title path: " + kDialogTitleLbl;
        return false;
    }
    
    if (!_ClickQuarterRow(row, err)) { run.ctx.lastError = err; return false; }
    
    run.ctx.Set("appliedIconQuarterRotationY", tostring(q));
    log("apply_saved_icon_rotation: applied quarter " + tostring(q) + " (row " + tostring(row) + ") via 14/" + kDialogRoot + "/2/" + tostring(row) + "/0", LogLevel::Info, 135, "Cmd_ApplySavedIconRotation");
    return true;
}

void RegisterApplySavedIconRotation(CommandRegistry@ R) {
    R.Register("apply_saved_icon_rotation", CommandFn(Cmd_ApplySavedIconRotation));
}

}}}