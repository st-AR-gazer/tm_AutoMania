namespace automata { namespace AutoStart {

const string kAutorunRel = "AutoMania/status/autorun.json";

bool gStarted = false;

string _AutorunAbs() { return IO::FromUserGameFolder(kAutorunRel); }

FlowDef@ _FindFlowByName(const string &in name) {
    string want = name.ToLower().Trim();
    for (uint i = 0; i < gFlows.Length; ++i) {
        if (gFlows[i] is null) continue;
        if (gFlows[i].name.ToLower().Trim() == want) return gFlows[i];
    }
    return null;
}

void _WaitForRunEnd() {
    while (automata::gActive !is null && (automata::gActive.status == FlowStatus::Running || automata::gActive.status == FlowStatus::Paused)) {
        yield(250);
    }
}

void _RunAutorunWorker() {
    yield(500);

    string abs = _AutorunAbs();
    if (!IO::FileExists(abs)) return;

    string txt = Helpers::FileIO::ReadTextFile(abs);
    if (txt.Length == 0) { Helpers::FileIO::DeleteIfExists(abs); return; }

    Json::Value@ req = Json::Parse(txt);
    if (req is null || req.GetType() != Json::Type::Object) { Helpers::FileIO::DeleteIfExists(abs); return; }

    Helpers::FileIO::DeleteIfExists(abs);

    string preName = req.HasKey("preflightFlow") ? string(req["preflightFlow"]) : "";
    Json::Value@ preParams = (req.HasKey("preflightParams") && req["preflightParams"].GetType() == Json::Type::Object)
        ? req["preflightParams"]
        : Json::Object();

    string mainName = req.HasKey("flow") ? string(req["flow"]) : "";
    Json::Value@ mainParams = (req.HasKey("params") && req["params"].GetType() == Json::Type::Object)
        ? req["params"]
        : Json::Object();

    if (mainName.Trim().Length == 0) {
        log("AutoStart: autorun.json missing 'flow'.", LogLevel::Warn, 49, "_RunAutorunWorker");
        return;
    }

    if (preName.Trim().Length > 0) {
        FlowDef@ pre = _FindFlowByName(preName);
        if (pre is null) {
            log("AutoStart: preflight flow not found: " + preName, LogLevel::Warn, 56, "_RunAutorunWorker");
        } else {
            log("AutoStart: running preflight: " + pre.name, LogLevel::Info, 58, "_RunAutorunWorker");
            automata::StartRun(pre, preParams);
            _WaitForRunEnd();

            if (automata::gActive !is null && automata::gActive.status == FlowStatus::Error) {
                log("AutoStart: preflight ended with error; main flow will NOT start.", LogLevel::Error, 63, "_RunAutorunWorker");
                return;
            }
        }
    }

    FlowDef@ main = _FindFlowByName(mainName);
    if (main is null) {
        log("AutoStart: main flow not found: " + mainName, LogLevel::Error, 71, "_RunAutorunWorker");
        return;
    }

    log("AutoStart: starting main flow: " + main.name, LogLevel::Info, 75, "_RunAutorunWorker");
    automata::StartRun(main, mainParams);
}

void Begin() {
    if (gStarted) return;
    gStarted = true;
    startnew(_RunAutorunWorker);
}

}}
