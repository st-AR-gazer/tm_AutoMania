namespace automata {

FlowRun@ gActive;

void _YieldFrames(int frames) {
    for (int i = 0; i < frames; ++i) yield();
}

void StartRun(FlowDef@ f, Json::Value@ runtimeParams) {
    if (gActive !is null && gActive.status == FlowStatus::Running) {
        log("A flow is already running.", LogLevel::Warn, 11, "StartRun");
        return;
    }
    @gActive = FlowRun(f);
    @gActive.params = runtimeParams is null ? Json::Object() : runtimeParams;

    if (f.display !is null && f.display.HasKey("overlay"))
        gActive.ctx.defaultOverlay = int(f.display["overlay"]);

    gActive.status = FlowStatus::Running;
    gActive.statusStr = "Starting…";

    automata::Helpers::FlowStatus::BeginRun(gActive);

    startnew(_RunActive);
}

void PauseOrResume() {
    if (gActive is null) return;
    if (gActive.status != FlowStatus::Running && gActive.status != FlowStatus::Paused) return;
    gActive.ctx.paused = !gActive.ctx.paused;
    gActive.status = gActive.ctx.paused ? FlowStatus::Paused : FlowStatus::Running;
    if (!gActive.ctx.paused) gActive.ctx.stepGateOpen = true;
    automata::Helpers::FlowStatus::OnRunEnd(gActive);
}

void StopRun() {
    if (gActive is null) return;
    gActive.ctx.cancelled = true;

    automata::Helpers::FlowStatus::OnRunEnd(gActive);
}

void _GateForStepOrPause() {
    if (gActive is null) return;
    while (gActive.ctx.paused || (gActive.ctx.stepMode && !gActive.ctx.stepGateOpen)) {
        if (gActive.ctx.cancelled) return;
        yield(33);
    }
    gActive.ctx.stepGateOpen = false;
}

void _RunActive() {
    FlowRun@ run = gActive;
    if (run is null) return;

    uint totalSteps = run.flow is null ? 0 : run.flow.TotalSteps();
    if (totalSteps == 0) {
        run.status = FlowStatus::Done;
        run.statusStr = "Done (no steps).";
        automata::Helpers::FlowStatus::OnRunEnd(run);
        return;
    }

    for (uint gi = 0; gi < totalSteps; ++gi) {
        run.ctx.stepIndex = gi;

        bool isPre = false;
        uint localIndex = 0;
        uint localTotal = 0;
        StepDef@ s = run.flow.GetStepByGlobalIndex(gi, isPre, localIndex, localTotal);
        if (s is null) break;

        run.ctx.Set("stepPhase", isPre ? "pre" : "main");
        run.ctx.Set("stepIndexLocal", tostring(localIndex));
        run.ctx.Set("stepCountLocal", tostring(localTotal));
        run.ctx.Set("stepCountGlobal", tostring(totalSteps));

        string phaseLabel = isPre ? "Pre" : "Step";

        run.statusStr =
            phaseLabel + " " + tostring(localIndex + 1) + "/" + tostring(localTotal)
            + " (global " + tostring(gi + 1) + "/" + tostring(totalSteps) + "): " + s.cmd;

        automata::Helpers::FlowStatus::OnStepStart(run, s.cmd);

        if (s.beforeFrames > 0) _YieldFrames(s.beforeFrames);
        else if (s.beforeMs > 0) yield(s.beforeMs);

        _GateForStepOrPause(); if (run.ctx.cancelled) break;

        log(">> " + phaseLabel + " " + tostring(localIndex + 1) + "/" + tostring(localTotal)
            + " (global " + tostring(gi + 1) + "/" + tostring(totalSteps) + "): " + s.cmd, LogLevel::Debug, 92, "_RunActive");




        bool ok = gCmds.Execute(s.cmd, run, s.args);
        if (!ok) {
            run.status = FlowStatus::Error;
            run.statusStr = "Error at " + phaseLabel + " " + tostring(localIndex + 1) + "/" + tostring(localTotal)
                + " (global " + tostring(gi + 1) + "/" + tostring(totalSteps) + "): " + s.cmd
                + " — " + run.ctx.lastError;

            log(run.statusStr, LogLevel::Error, 104, "_RunActive");

            Json::Value@ extra = Json::Object();
            extra["failedCmd"] = s.cmd;
            extra["stepIndex"] = int(gi);
            extra["stepPhase"] = isPre ? "pre" : "main";
            extra["stepIndexLocal"] = int(localIndex);
            extra["lastError"] = run.ctx.lastError;
            automata::Helpers::FlowStatus::RecordEvent(run, "error", "flow.step_failed", run.statusStr, extra);

            automata::Helpers::CrashWatch::ClearIntent("cleared", "Flow ended with error (not a crash).");

            automata::Helpers::FlowStatus::OnRunEnd(run);
            return;
        }

        log("<< " + phaseLabel + " " + tostring(localIndex + 1) + " OK: " + s.cmd, LogLevel::Debug, 120, "_RunActive");

        automata::Helpers::FlowStatus::OnStepOk(run, s.cmd);

        if (s.afterFrames > 0) _YieldFrames(s.afterFrames);
        else if (s.afterMs > 0) yield(s.afterMs);

        if (run.ctx.jumpToStep >= 0) {
            int j = run.ctx.jumpToStep;
            run.ctx.jumpToStep = -1;

            if (j >= 0 && j < int(totalSteps)) {
                gi = uint(j);
                gi--;
                continue;
            }
        }

        if (run.ctx.stepMode) run.ctx.stepGateOpen = false;
        _GateForStepOrPause(); if (run.ctx.cancelled) break;
    }

    if (run.ctx.cancelled) {
        run.status = FlowStatus::Idle;
        run.statusStr = "Cancelled.";
    } else if (run.status != FlowStatus::Error) {
        run.status = FlowStatus::Done;
        run.statusStr = "Done.";
    }

    automata::Helpers::CrashWatch::ClearIntent("cleared", "Flow finished/cancelled.");
    automata::Helpers::FlowStatus::OnRunEnd(run);
}

}
