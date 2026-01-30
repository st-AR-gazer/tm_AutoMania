namespace automata { namespace Helpers { namespace Cmd_OpenItemEditor_EditorPlusPlus {

const uint   OVL_CANNOT_CONVERT = 12;
const string PATH_CANNOT_LABEL  = "1/0/2/1";
const string PATH_CANNOT_OKBTN  = "1/0/2/0/0";
const string NEEDLE_CANNOT_CONVERT = "cannot convert this block into a custom block";

string _toLower(const string &in s) { return s.ToLower(); }

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
    if (run.ctx.GetString("warningsCount", cS) && cS.Length > 0) {
        c = Text::ParseInt(cS);
    }
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

    log("OpenItemEditor(epp): Cannot convert popup detected for '" + blockCanonForRecord + "'. Clicking OK + skipping.", LogLevel::Warn, 72, "_DismissCannotConvertPopupIfPresent");

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

bool OpenItemEditor(const string &in modeIn, const string &in blockNameIn, string &out err) {
    err = "";

    CGameCtnApp@ app = GetApp();
    if (app is null) { err = "App is null."; return false; }

    
    if (cast<CGameEditorItem>(app.Editor) !is null) {
        log("OpenItemEditor(epp): Item Editor already open.", LogLevel::Info, 100, "OpenItemEditor");
        FlowRun@ run = automata::gActive;
        if (run !is null) run.ctx.Set("itemEditorOpened", "1");
        return true;
    }

    
    CGameCtnEditorFree@ edFree = cast<CGameCtnEditorFree>(app.Editor);
    if (edFree is null) {
        err = "Not in Map Editor Free (CGameCtnEditorFree). Open a map in the Free editor first.";
        return false;
    }

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

    Editor::OpenItemEditor(edFree, info);
    yield();

    if (_DismissCannotConvertPopupIfPresent(canonical)) {
        return true;
    }

    uint until = Time::Now + 6000;
    while (Time::Now < until) {
        if (cast<CGameEditorItem>(app.Editor) !is null) {
            log("OpenItemEditor(epp): Item Editor is open for '" + canonical + "'.", LogLevel::Info, 135, "OpenItemEditor");
            FlowRun@ run = automata::gActive;
            if (run !is null) {
                run.ctx.Set("itemEditorOpened", "1");
                run.ctx.Set("itemEditorSkipReason", "");
            }
            return true;
        }

        if (_DismissCannotConvertPopupIfPresent(canonical)) {
            return true;
        }

        yield(10);
    }

    err = "Editor++ export call did not result in Item Editor opening (timeout).";
    return false;
}

}}}