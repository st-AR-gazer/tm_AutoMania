namespace automata { namespace Helpers { namespace Cmd_OpenItemEditor_EditorPlusPlus {

bool OpenItemEditor(const string &in modeIn, const string &in blockNameIn, string &out err) {
    err = "";

    CGameCtnApp@ app = GetApp();
    if (app is null) { err = "App is null."; return false; }

    
    if (cast<CGameEditorItem>(app.Editor) !is null) {
        log("OpenItemEditor(epp): Item Editor already open.", LogLevel::Info, 11, "OpenItemEditor");
        FlowRun@ run = automata::gActive;
        if (run !is null) run.ctx.Set("itemEditorOpened", "1");
        return true;
    }
    
    CGameCtnEditorFree@ edFree = cast<CGameCtnEditorFree>(app.Editor);
    if (edFree is null) {
        err = "Not in Map Editor Free (CGameCtnEditorFree). Open a map in the Free editor first.";
        return false;
    }

    string mode = modeIn.ToLower();
    if (mode != "block-to-block" && mode != "block-to-item") {
        err = "Unknown mode '" + modeIn + "'. Expected 'block-to-block' or 'block-to-item'.";
        return false;
    }

    CGameCtnBlockInfo@ info; string canonical; string rerr;
    if (!automata::Helpers::Blocks::TryFindBlockInfoByName(blockNameIn, info, canonical, rerr)) {
        err = "Block not found: " + blockNameIn + (rerr.Length > 0 ? " | " + rerr : "");
        return false;
    }

    Editor::OpenItemEditor(edFree, info);
    yield();

    if (Helpers::ItemEditorWarnings::HandleCannotConvertPopup(canonical, "OpenItemEditor(epp)", 72, "_DismissCannotConvertPopupIfPresent")) {
        return true;
    }

    uint until = Time::Now + 6000;
    while (Time::Now < until) {
        if (cast<CGameEditorItem>(app.Editor) !is null) {
            log("OpenItemEditor(epp): Item Editor is open for '" + canonical + "'.", LogLevel::Info, 46, "OpenItemEditor");
            FlowRun@ run = automata::gActive;
            if (run !is null) {
                run.ctx.Set("itemEditorOpened", "1");
                run.ctx.Set("itemEditorSkipReason", "");
            }
            return true;
        }

        if (Helpers::ItemEditorWarnings::HandleCannotConvertPopup(canonical, "OpenItemEditor(epp)", 72, "_DismissCannotConvertPopupIfPresent")) {
            return true;
        }

        yield(10);
    }

    err = "Editor++ export call did not result in Item Editor opening (timeout).";
    return false;
}

}}}
