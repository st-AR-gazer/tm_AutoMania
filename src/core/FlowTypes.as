namespace automata {

enum FlowStatus { Idle, Running, Paused, Done, Error }

class StepDef {
    string cmd;
    Json::Value@ args;

    int beforeMs = 0;
    int afterMs  = 0;

    int beforeFrames = 0;
    int afterFrames  = 0;

    StepDef() { @args = null; }
}

class FlowDef {
    string name;
    int version = 1;
    Json::Value@ paramsSpec;
    
    array<StepDef@> preSteps;
    array<StepDef@> steps;

    Json::Value@ display;
    string sourcePath;

    uint TotalSteps() {
        return preSteps.Length + steps.Length;
    }

    StepDef@ GetStepByGlobalIndex(uint globalIndex, bool &out isPre, uint &out localIndex, uint &out localTotal) {
        uint preLen = preSteps.Length;

        if (globalIndex < preLen) {
            isPre = true;
            localIndex = globalIndex;
            localTotal = preLen;
            return preSteps[globalIndex];
        }

        uint mainIdx = globalIndex - preLen;
        isPre = false;
        localIndex = mainIdx;
        localTotal = steps.Length;

        if (mainIdx < steps.Length) return steps[mainIdx];
        return null;
    }
}

class RunCtx {
    dictionary kv;
    string statusStr;
    uint startTime = 0;
    uint stepIndex = 0;
    bool cancelled = false;
    bool paused = false;
    bool stepMode = false;
    bool stepGateOpen = false;
    string lastError;
    int defaultOverlay = 16;

    Json::Value@ batchList;
    int  batchIndex = -1;
    int  loopStartStep = -1;
    int  loopEndStep = -1;
    bool loopActive = false;
    int  jumpToStep = -1;

    bool Has(const string &in k) { return kv.Exists(k); }
    bool GetString(const string &in k, string &out v) {
        if (!kv.Exists(k)) return false; v = string(kv[k]); return true;
    }
    void Set(const string &in k, const string &in v) { kv[k] = v; }
    void SetInt(const string &in k, int v) { kv[k] = v; }
    void SetFloat(const string &in k, float v) { kv[k] = v; }
    void SetBool(const string &in k, bool v) { kv[k] = v; }
}

class FlowRun {
    FlowDef@ flow;
    RunCtx ctx;
    Json::Value@ params;
    FlowStatus status = FlowStatus::Idle;
    string statusStr;

    FlowRun(FlowDef@ f) { @flow = f; ctx.startTime = Time::Now; }
}

}
