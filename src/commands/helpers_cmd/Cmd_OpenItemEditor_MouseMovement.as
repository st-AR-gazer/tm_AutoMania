namespace automata { namespace Helpers { namespace Cmd_OpenItemEditor_MouseMovement {

const int   kOpenMaxAttempts    = 20;    
const int   kPostClickYield     = 2;     
const int   kSettleFramesShort  = 6;     
const int   kWaitItemEditorMs   = 3000;  

bool _IsItemEditorOpen(CGameCtnApp@ app) {
    return cast<CGameEditorItem>(app.Editor) !is null;
}

bool _WaitForItemEditor(CGameCtnApp@ app, int timeoutMs) {
    uint until = Time::Now + uint(timeoutMs);
    while (Time::Now < until) {
        if (_IsItemEditorOpen(app)) return true;
        yield(10);
    }
    return _IsItemEditorOpen(app);
}

CGameCtnBlock@ _PlaceOne(CGameCtnApp@ app, CGameCtnEditorCommon@ editor, CGameEditorPluginMapMapType@ pmt, CGameCtnBlockInfo@ info) {
    pmt.PlaceMode = CGameEditorPluginMap::EPlaceMode::GhostBlock;
    @pmt.CursorBlockModel = info;
    
    for (int i = 0; i < 6; ++i) yield();

    uint before = pmt.Blocks.Length;

    if (::mouse is null) {
        log("OpenItemEditor(mouse): mouse controller not available; cannot place.", LogLevel::Error, 30, "_PlaceOne");
        return null;
    }
    
    ::mouse.Click();
    yield(2);

    for (int attempt = 0; attempt < 25; ++attempt) {
        ::mouse.Click();
        yield();

        if (pmt.Blocks.Length > before) {
            CGameCtnBlock@ placed = pmt.Blocks[pmt.Blocks.Length - 1];
            log("OpenItemEditor(mouse): placed '" + info.Name + "' (Blocks: " + before + " -> " + pmt.Blocks.Length + ")", LogLevel::Info, 43, "_PlaceOne");
            return placed;
        }
    }

    log("\\$ff0[WARN] OpenItemEditor(mouse): failed to place block - hold NUMPAD3 for the DLL to accept input, ensure cursor is over placeable grid and the game window is focused.", LogLevel::Warn, 48, "_PlaceOne");

    return null;
}

bool _ClickToOpenItemEditor(CGameCtnApp@ app, CGameCtnEditorCommon@ editor, const string &in canonical, bool &out cannotConvert) {
    cannotConvert = false;

    for (int attempt = 0; attempt < kOpenMaxAttempts; ++attempt) {
        if (_IsItemEditorOpen(app)) return true;
        
        ::mouse.Click();

        for (int f = 0; f < kPostClickYield; ++f) {
            yield();

            if (_IsItemEditorOpen(app)) return true;

            if (Helpers::ItemEditorWarnings::HandleCannotConvertPopup(canonical, "OpenItemEditor(mouse)", 87, "_DismissCannotConvertPopupIfPresent")) {
                cannotConvert = true;
                return false;
            }
        }
    }
    return _IsItemEditorOpen(app);
}

bool OpenItemEditor(const string &in modeIn, const string &in blockNameIn, string &out err) {
    err = "";

    CGameCtnApp@ app = GetApp();
    if (app is null) { err = "App is null."; return false; }

    CGameCtnEditorCommon@ editor = cast<CGameCtnEditorCommon@>(app.Editor);
    if (editor is null) { err = "Not in Map Editor. Open a map first."; return false; }

    CGameEditorPluginMapMapType@ pmt = editor.PluginMapType;
    if (pmt is null) { err = "PluginMapType is null."; return false; }

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
    
    CGameCtnBlock@ placed = _PlaceOne(app, editor, pmt, info);
    if (placed is null) {
        err = "Could not place '" + canonical + "'. Is the cursor over a placeable area? Is the window focused?";
        return false;
    }
    
    CGameCtnEditorFree@ edFree = cast<CGameCtnEditorFree>(editor);
    if (edFree !is null) {
        Editor::SetEditorPickedBlock(edFree, placed);
        yield();
    }

    if (mode == "block-to-item") {
        editor.ButtonItemCreateFromBlockModeOnClick();
        log("OpenItemEditor(mouse): switched to 'Item Create From Block' mode.", LogLevel::Info, 115, "OpenItemEditor");
    } else {
        editor.ButtonBlockItemCreateModeOnClick();
        log("OpenItemEditor(mouse): switched to 'Block → CustomBlock' mode.", LogLevel::Info, 118, "OpenItemEditor");
    }

    yield(kSettleFramesShort);

    if (::mouse is null) {
        err = "Mouse controller not available to confirm selection.";
        return false;
    }

    bool cannotConvert = false;
    bool opened = _ClickToOpenItemEditor(app, editor, canonical, cannotConvert);

    if (!opened) {
        if (cannotConvert) return true;

        if (!_WaitForItemEditor(app, kWaitItemEditorMs)) {
            err = "Item Editor did not open after clicking the placed block.";
            return false;
        }
    }

    FlowRun@ run = automata::gActive;
    if (run !is null) {
        run.ctx.Set("itemEditorOpened", "1");
        run.ctx.Set("itemEditorSkipReason", "");
    }

    log("OpenItemEditor(mouse): Item Editor is open.", LogLevel::Info, 146, "OpenItemEditor");
    return true;
}

}}}
