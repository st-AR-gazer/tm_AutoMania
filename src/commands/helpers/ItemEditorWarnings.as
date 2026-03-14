namespace automata { namespace Helpers { namespace ItemEditorWarnings {

const uint   OVL_CANNOT_CONVERT = 12;
const string PATH_CANNOT_LABEL  = "1/0/2/1";
const string PATH_CANNOT_OKBTN  = "1/0/2/0/0";
const string NEEDLE_CANNOT_CONVERT = "cannot convert this block into a custom block";

bool _DetectCannotConvert(string &out rawText) {
    CControlBase@ lbl = UiNav::ResolvePath(PATH_CANNOT_LABEL, OVL_CANNOT_CONVERT);
    if (lbl is null) return false;
    rawText = UiNav::ReadText(lbl);
    string cmp = UiNav::NormalizeForCompare(rawText).ToLower();
    return cmp.IndexOf(NEEDLE_CANNOT_CONVERT) >= 0;
}

void _RecordCannotConvert(FlowRun@ run, const string &in blockCanon, const string &in rawMsg) {
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

bool HandleCannotConvertPopup(const string &in blockCanonForRecord, const string &in logPrefix, int line, const string &in fnName) {
    string raw;
    if (!_DetectCannotConvert(raw)) return false;

    FlowRun@ run = automata::gActive;

    string p = logPrefix.Length > 0 ? (logPrefix + ": ") : "";
    log(p + "Cannot convert popup detected for '" + blockCanonForRecord + "'. Clicking OK + skipping.", LogLevel::Warn, 65, "HandleCannotConvertPopup");

    _RecordCannotConvert(run, blockCanonForRecord, raw);

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

}}}
