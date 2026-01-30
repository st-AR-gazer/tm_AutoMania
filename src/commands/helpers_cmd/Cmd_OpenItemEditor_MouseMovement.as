namespace automata { namespace Helpers { namespace Cmd_OpenItemEditor_MouseMovement {

const int   kOpenMaxAttempts    = 20;    
const int   kPostClickYield     = 2;     
const int   kSettleFramesShort  = 6;     
const int   kWaitItemEditorMs   = 3000;  

const uint   OVL_CANNOT_CONVERT = 12;
const string PATH_CANNOT_LABEL  = "1/0/2/1";
const string PATH_CANNOT_OKBTN  = "1/0/2/0/0";
const string NEEDLE_CANNOT_CONVERT = "cannot convert this block into a custom block";

string _toLower(const string &in s) { return s.ToLower(); }

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

bool _TryResolveBlockInfo(const string &in nameIn, CGameCtnBlockInfo@ &out info, string &out canonical, string &out err) {
    if (!automata::Helpers::Blocks::TryFindBlockInfoByName(nameIn, info, canonical, err)) {
        return false;
    }
    return true;
}

void _RecordWarning_CannotConvert(FlowRun@ run, const string &in blockCanon, const string &in rawMsg) {
    if (run is null) return;

    string lastB, lastS;
    run.ctx.GetString("lastCannotConvertBlock", lastB);
    run.ctx.GetString("lastCannotConvertStep",  lastS);
    string curS = tostring(int(run.ctx.stepIndex));
    if (lastB == blockCanon && lastS == curS) return;

    run.ctx.Set("lastCannotConvertBlock", blockCanon);
    run.ctx.Set("lastCannotConvertStep",  curS);

    Json::Value@ ev = Json::Object();
    ev["type"]     = "item_editor_cannot_convert";
    ev["block"]    = blockCanon;
    ev["message"]  = rawMsg;
    ev["overlay"]  = int(OVL_CANNOT_CONVERT);
    ev["path"]     = PATH_CANNOT_LABEL;
    ev["step"]     = int(run.ctx.stepIndex);
    ev["timeNow"]  = int(Time::Now);
    if (run.flow !is null) ev["flow"] = run.flow.name;

    string line = Json::Write(ev, false);

    string prev;
    bool had = run.ctx.GetString("warningsJsonl", prev);
    if (had && prev.Length > 0) prev += line + "\n";
    else                        prev  = line + "\n";
    run.ctx.Set("warningsJsonl", prev);

    run.ctx.Set("lastWarningType",    "item_editor_cannot_convert");
    run.ctx.Set("lastWarningBlock",   blockCanon);
    run.ctx.Set("lastWarningMessage", rawMsg);
    run.ctx.Set("lastWarningStep",    curS);

    string cS;
    int c = 0;
    if (run.ctx.GetString("warningsCount", cS) && cS.Length > 0) c = Text::ParseInt(cS);
    c++;
    run.ctx.Set("warningsCount", tostring(c));
}

bool _DismissCannotConvertPopupIfPresent(const string &in blockCanonForRecord) {
    CControlBase@ lbl = UiNav::ResolvePath(PATH_CANNOT_LABEL, OVL_CANNOT_CONVERT);
    if (lbl is null) return false;

    string raw = UiNav::ReadText(lbl);
    string cmp = UiNav::NormalizeForCompare(raw).ToLower();
    if (cmp.IndexOf(NEEDLE_CANNOT_CONVERT) < 0) return false;

    FlowRun@ run = automata::gActive;

    log("OpenItemEditor(mouse): Cannot convert popup detected for '" + blockCanonForRecord + "'. Clicking OK + skipping.", LogLevel::Warn, 87, "_DismissCannotConvertPopupIfPresent");

    _RecordWarning_CannotConvert(run, blockCanonForRecord, raw);

    UiNav::ClickPath(PATH_CANNOT_OKBTN, OVL_CANNOT_CONVERT);
    yield();

    if (run !is null) {
        run.ctx.Set("itemEditorOpened", "0");
        run.ctx.Set("itemEditorSkipReason", "cannot_convert");
        if (run.ctx.loopActive && run.ctx.loopEndStep >= 0) {
            run.ctx.jumpToStep = run.ctx.loopEndStep;
        }
    }

    return true;
}

CGameCtnBlock@ _PlaceOne(CGameCtnApp@ app, CGameCtnEditorCommon@ editor, CGameEditorPluginMapMapType@ pmt, CGameCtnBlockInfo@ info) {
    pmt.PlaceMode = CGameEditorPluginMap::EPlaceMode::GhostBlock;
    @pmt.CursorBlockModel = info;
    
    for (int i = 0; i < 6; ++i) yield();

    uint before = pmt.Blocks.Length;

    if (::mouse is null) {
        log("OpenItemEditor(mouse): mouse controller not available; cannot place.", LogLevel::Error, 114, "_PlaceOne");
        return null;
    }
    
    ::mouse.Click();
    yield(2);

    for (int attempt = 0; attempt < 25; ++attempt) {
        ::mouse.Click();
        yield();

        if (pmt.Blocks.Length > before) {
            CGameCtnBlock@ placed = pmt.Blocks[pmt.Blocks.Length - 1];
            log("OpenItemEditor(mouse): placed '" + info.Name + "' (Blocks: " + before + " -> " + pmt.Blocks.Length + ")", LogLevel::Info, 127, "_PlaceOne");
            return placed;
        }
    }

    log("\\$ff0[WARN] OpenItemEditor(mouse): failed to place block — "
        "hold NUMPAD3 for the DLL to accept input, ensure cursor is over placeable grid and the game window is focused.", LogLevel::Warn, 132, "_PlaceOne");


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

            if (_DismissCannotConvertPopupIfPresent(canonical)) {
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

    string mode = _toLower(modeIn);
    if (mode != "block-to-block" && mode != "block-to-item") {
        err = "Unknown mode '" + modeIn + "'. Expected 'block-to-block' or 'block-to-item'.";
        return false;
    }
    
    CGameCtnBlockInfo@ info; string canonical; string rerr;
    if (!_TryResolveBlockInfo(blockNameIn, info, canonical, rerr)) {
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
        log("OpenItemEditor(mouse): switched to 'Item Create From Block' mode.", LogLevel::Info, 198, "OpenItemEditor");
    } else {
        editor.ButtonBlockItemCreateModeOnClick();
        log("OpenItemEditor(mouse): switched to 'Block → CustomBlock' mode.", LogLevel::Info, 201, "OpenItemEditor");
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

    log("OpenItemEditor(mouse): Item Editor is open.", LogLevel::Info, 229, "OpenItemEditor");
    return true;
}

}}}