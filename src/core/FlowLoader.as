namespace automata {

array<FlowDef@> gFlows;

bool _TryGetInt(Json::Value@ o, const string &in a, int &out v) {
    if (o is null) return false;
    if (o.HasKey(a)) { v = int(o[a]); return true; }
    return false;
}

int _StepMs(Json::Value@ s, const string &in k1, const string &in k2) {
    int v = 0, tmp = 0;
    if (_TryGetInt(s, k1, tmp)) v = tmp;
    if (_TryGetInt(s, k2, tmp)) v = tmp;
    return v;
}

StepDef@ _ParseStep(Json::Value@ st) {
    StepDef@ s = StepDef();
    s.cmd  = st.HasKey("cmd")  ? string(st["cmd"])  : "";
    @s.args = st.HasKey("args") ? st["args"] : Json::Object();

    if (st.HasKey("before_ms"))      s.beforeMs = int(st["before_ms"]);
    else if (st.HasKey("beforeMs"))  s.beforeMs = int(st["beforeMs"]);

    if (st.HasKey("after_ms"))       s.afterMs = int(st["after_ms"]);
    else if (st.HasKey("afterMs"))   s.afterMs = int(st["afterMs"]);

    if (st.HasKey("before_frames"))  s.beforeFrames = int(st["before_frames"]);
    else if (st.HasKey("beforeFrames")) s.beforeFrames = int(st["beforeFrames"]);

    if (st.HasKey("after_frames"))   s.afterFrames = int(st["after_frames"]);
    else if (st.HasKey("afterFrames")) s.afterFrames = int(st["afterFrames"]);

    return s;
}

Json::Value@ _GetPreStepsArray(Json::Value@ preVal) {
    if (preVal is null) return null;

    if (preVal.GetType() == Json::Type::Array) return preVal;

    if (preVal.GetType() == Json::Type::Object) {
        if (preVal.HasKey("steps") && preVal["steps"].GetType() == Json::Type::Array) {
            return preVal["steps"];
        }
    }

    return null;
}

FlowDef@ _ParseFlow(const string &in path, Json::Value@ root) {
    if (root is null || root.GetType() != Json::Type::Object) return null;
    if (!root.HasKey("name")) return null;

    Json::Value@ stepsA = null;
    if (root.HasKey("steps") && root["steps"].GetType() == Json::Type::Array) {
        @stepsA = root["steps"];
    }

    Json::Value@ preA = null;
    if (root.HasKey("pre")) {
        @preA = _GetPreStepsArray(root["pre"]);
    }

    bool hasAny = false;
    if (stepsA !is null && stepsA.Length > 0) hasAny = true;
    if (preA !is null && preA.Length > 0) hasAny = true;
    if (!hasAny) return null;

    FlowDef f;
    f.name = string(root["name"]);
    if (root.HasKey("version")) f.version = int(root["version"]);
    @f.paramsSpec = root.HasKey("params") ? root["params"] : Json::Object();
    @f.display = root.HasKey("display") ? root["display"] : Json::Object();
    f.sourcePath = path;

    if (preA !is null) {
        for (uint i = 0; i < preA.Length; ++i) {
            StepDef@ s = _ParseStep(preA[i]);
            if (s is null) {
                log("Skipping invalid PRE step in " + path + " idx=" + i, LogLevel::Warn, 82, "_ParseFlow");
                continue;
            }
            if (s.cmd.Trim().Length == 0) {
                log("Skipping PRE step with empty cmd in " + path + " idx=" + i, LogLevel::Warn, 86, "_ParseFlow");
                continue;
            }
            f.preSteps.InsertLast(s);
        }
    }

    if (stepsA !is null) {
        for (uint i = 0; i < stepsA.Length; ++i) {
            StepDef@ s = _ParseStep(stepsA[i]);
            if (s is null) {
                log("Skipping invalid step in " + path + " idx=" + i, LogLevel::Warn, 97, "_ParseFlow");
                continue;
            }
            if (s.cmd.Trim().Length == 0) {
                log("Skipping step with empty cmd in " + path + " idx=" + i, LogLevel::Warn, 101, "_ParseFlow");
                continue;
            }
            f.steps.InsertLast(s);
        }
    }

    if (f.preSteps.Length == 0 && f.steps.Length == 0) return null;

    return f;
}

void _SortFlows() {
    for (uint i = 0; i + 1 < gFlows.Length; ++i) {
        for (uint j = i + 1; j < gFlows.Length; ++j) {
            auto a = gFlows[i];
            auto b = gFlows[j];
            int ao = 0, bo = 0;
            if (a.display !is null && a.display.HasKey("order")) ao = int(a.display["order"]);
            if (b.display !is null && b.display.HasKey("order")) bo = int(b.display["order"]);
            bool swap = false;
            if (ao != bo) swap = ao > bo;
            else swap = a.name > b.name;
            if (swap) {
                auto tmp = gFlows[i];
                @gFlows[i] = gFlows[j];
                @gFlows[j] = tmp;
            }
        }
    }
}

void ReloadFlows() {
    gFlows.RemoveRange(0, gFlows.Length);
    string dir = IO::FromStorageFolder("flows/");
    if (!IO::FolderExists(dir)) {
        IO::CreateFolder(dir);
        log("Created flows folder: " + dir, LogLevel::Info, 138, "ReloadFlows");
    }
    array<string>@ files = IO::IndexFolder(dir, false);
    if (files is null) {
        log("IndexFolder returned null for: " + dir, LogLevel::Warn, 142, "ReloadFlows");
        return;
    }
    for (uint i = 0; i < files.Length; ++i) {
        string p = files[i];
        if (!p.EndsWith(".json")) continue;
        string nameOnly = Path::GetFileName(p);
        if (!nameOnly.StartsWith("flow.")) continue;

        string data = _IO::File::ReadFileToEnd(p, false);
        if (data.Length == 0) { log("Empty or unreadable: " + p, LogLevel::Warn, 152, "ReloadFlows"); continue; }
        Json::Value@ j = Json::Parse(data);
        if (j is null) { log("JSON parse failed: " + p, LogLevel::Error, 154, "ReloadFlows"); continue; }
        FlowDef@ f = _ParseFlow(p, j);
        if (f is null) { log("Failed to parse flow: " + p, LogLevel::Error, 156, "ReloadFlows"); continue; }
        gFlows.InsertLast(f);
    }
    _SortFlows();
    log("Loaded " + gFlows.Length + " flow(s).", LogLevel::Info, 160, "ReloadFlows");
}

}
