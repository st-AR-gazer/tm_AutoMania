namespace automata { namespace UI_FlowEditor {

class EditorTab {
    int uid;
    FlowDef@ editing;
    string name = "New Flow";
    int version = 1;
    Json::Value@ paramsSpec;
    array<StepDef@> steps;
    Json::Value@ display;
    int overlay = 16;

    bool showReorderPanel = false;
    array<int> reorderToIndex;
    string newParamName = "";
    string promoteArgPath = "";
    string promoteParamName = "";

    EditorTab() {
        @paramsSpec = Json::Object();
        @display = Json::Object();
        display["overlay"] = overlay;
    }

    void EnsureReorderArray() {
        reorderToIndex.Resize(steps.Length);
        for (uint i = 0; i < steps.Length; ++i) reorderToIndex[i] = int(i);
    }
}

bool gShow = false;
array<EditorTab@> gTabs;
int gActiveTab = -1;
int gNextTabUid = 1;

string SanitizeFileName(const string &in name) {
    string s = name.Replace(" ", "_");
    string outS = "";
    for (int i = 0; i < s.Length; i++) {
        string ch = s.SubStr(i, 1);
        if ((ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z")
            || (ch >= "0" && ch <= "9") || ch == "_" || ch == "-" || ch == ".") {
            outS += ch;
        }
    }
    if (outS.Length == 0) outS = "flow";
    return outS;
}

void Tab_MoveStep(EditorTab@ t, uint from, uint to) {
    if (from >= t.steps.Length) return;
    if (t.steps.Length == 0) return;
    if (to >= t.steps.Length) to = t.steps.Length - 1;
    if (from == to) return;

    StepDef@ tmp = t.steps[from];
    t.steps.RemoveAt(from);

    if (to > from) to--;

    t.steps.InsertLast(tmp);
    uint last = t.steps.Length - 1;
    for (uint i = last; i > to; --i) {
        auto a = t.steps[i-1];
        @t.steps[i-1] = t.steps[i];
        @t.steps[i]   = a;
    }
}

void Tab_InsertStepAt(EditorTab@ t, StepDef@ s, uint at) {
    t.steps.InsertLast(s);
    if (t.steps.Length == 1) return;
    Tab_MoveStep(t, t.steps.Length - 1, at);
}

bool _IsScopeOpen(const string &in cmd)  { return cmd == "batch_loop_begin"; }
bool _IsScopeClose(const string &in cmd) { return cmd == "batch_loop_end"; }
bool _IsScopeElse(const string &in cmd)  { return false; }

string _ScopeBadge(const string &in cmd) {
    if (cmd == "batch_loop_begin") return "⟲ LOOP";
    if (cmd == "batch_loop_end")   return "⟲ END";
    return "";
}

array<int> _ComputeIndentLevels(EditorTab@ t) {
    array<int> levels; levels.Resize(t.steps.Length);
    int depth = 0;
    for (uint i = 0; i < t.steps.Length; ++i) {
        auto s = t.steps[i];
        string cmd = s is null ? "" : s.cmd;

        if (_IsScopeClose(cmd) || _IsScopeElse(cmd)) {
            depth -= 1;
            if (depth < 0) depth = 0;
        }

        levels[i] = depth;

        if (_IsScopeOpen(cmd) || _IsScopeElse(cmd)) {
            depth += 1;
        }
    }
    return levels;
}

void _FocusTab(int idx) {
    if (idx < 0 || idx >= int(gTabs.Length)) return;
    gActiveTab = idx;
    gShow = true;
}

void NewFlow() {
    EditorTab@ t = EditorTab();
    t.uid = gNextTabUid++;
    gTabs.InsertLast(t);
    _FocusTab(gTabs.Length - 1);
}

void OpenFlow(FlowDef@ f) {
    EditorTab@ t = EditorTab();
    t.uid = gNextTabUid++;
    @t.editing = f;
    t.name = f.name;
    t.version = f.version;
    @t.paramsSpec = automata::JsonDeepClone(f.paramsSpec is null ? Json::Object() : f.paramsSpec);
    t.steps.RemoveRange(0, t.steps.Length);
    for (uint i = 0; i < f.steps.Length; ++i) {
        StepDef@ s = StepDef();
        s.cmd = f.steps[i].cmd;
        @s.args = automata::JsonDeepClone(f.steps[i].args);
        s.beforeMs     = f.steps[i].beforeMs;
        s.afterMs      = f.steps[i].afterMs;
        s.beforeFrames = f.steps[i].beforeFrames;
        s.afterFrames  = f.steps[i].afterFrames;
        t.steps.InsertLast(s);
    }
    @t.display = automata::JsonDeepClone(f.display is null ? Json::Object() : f.display);
    t.overlay = t.display.HasKey("overlay") ? int(t.display["overlay"]) : 16;
    t.showReorderPanel = false;
    t.EnsureReorderArray();

    gTabs.InsertLast(t);
    _FocusTab(gTabs.Length - 1);
}

void _Save(EditorTab@ t) {
    Json::Value root = Json::Object();
    root["name"] = t.name;
    root["version"] = t.version;
    root["params"] = t.paramsSpec is null ? Json::Object() : t.paramsSpec;

    Json::Value stepsA = Json::Array();
    for (uint i = 0; i < t.steps.Length; ++i) {
        Json::Value s = Json::Object();
        s["cmd"] = t.steps[i].cmd;
        if (t.steps[i].args !is null) s["args"] = t.steps[i].args;
        if (t.steps[i].beforeMs     > 0) s["before_ms"]     = t.steps[i].beforeMs;
        if (t.steps[i].afterMs      > 0) s["after_ms"]      = t.steps[i].afterMs;
        if (t.steps[i].beforeFrames > 0) s["before_frames"] = t.steps[i].beforeFrames;
        if (t.steps[i].afterFrames  > 0) s["after_frames"]  = t.steps[i].afterFrames;
        stepsA.Add(s);
    }
    root["steps"] = stepsA;

    if (t.display is null) @t.display = Json::Object();
    t.display["overlay"] = t.overlay;
    root["display"] = t.display;

    string dir = IO::FromStorageFolder("flows/");
    if (!IO::FolderExists(dir)) IO::CreateFolder(dir);
    string fname = "flow." + SanitizeFileName(t.name) + ".json";
    string path = dir + fname;

    _IO::File::WriteFile(path, Json::Write(root, true), false);
    ReloadFlows();
}

void _RenderParams(EditorTab@ t) {
    if (!UI::CollapsingHeader("Parameters##params-"+tostring(t.uid))) return;
    if (t.paramsSpec is null) @t.paramsSpec = Json::Object();

    UI::PushID("params-"+tostring(t.uid));
    array<string>@ keys = t.paramsSpec.GetKeys();
    for (uint i = 0; i < keys.Length; ++i) {
        string k = keys[i];
        Json::Value@ spec = t.paramsSpec[k];

        UI::PushID(k);
        UI::Text(k);
        UI::SameLine();

        string typ = spec.HasKey("type") ? string(spec["type"]) : "string";
        UI::SetNextItemWidth(110.0f);
        if (UI::BeginCombo("##type", typ)) {
            array<string> types = {"string","int","float","bool"};
            for (uint ti = 0; ti < types.Length; ++ti) {
                bool sel = types[ti] == typ;
                if (UI::Selectable(types[ti], sel)) {
                    typ = types[ti];
                    spec["type"] = typ;
                }
            }
            UI::EndCombo();
        }
        UI::SameLine();

        if (typ == "int") {
            int v = spec.HasKey("default") ? int(spec["default"]) : 0;
            v = UI::InputInt("##defi", v);
            spec["default"] = v;
        } else if (typ == "float") {
            float v = spec.HasKey("default") ? float(spec["default"]) : 0.0f;
            v = UI::InputFloat("##deff", v);
            spec["default"] = v;
        } else if (typ == "bool") {
            bool v = spec.HasKey("default") ? bool(spec["default"]) : false;
            v = UI::Checkbox("##defb", v);
            spec["default"] = v;
        } else {
            string v = spec.HasKey("default") ? string(spec["default"]) : "";
            v = UI::InputText("##defs", v);
            spec["default"] = v;
        }

        UI::SameLine();
        if (UI::Button("Delete")) {
            t.paramsSpec.Remove(k);
            UI::PopID();
            continue;
        }
        UI::PopID();
    }

    UI::Separator();
    UI::SetNextItemWidth(180.0f);
    t.newParamName = UI::InputText("New param name", t.newParamName);
    UI::SameLine();
    if (UI::Button("Add Param")) {
        if (t.newParamName.Length > 0 && !t.paramsSpec.HasKey(t.newParamName)) {
            Json::Value d = Json::Object();
            d["type"] = "string"; d["default"] = "";
            t.paramsSpec[t.newParamName] = d;
            t.newParamName = "";
        }
    }
    UI::PopID();
}

int _RenderTimeoutInput(const string &in label, int value, const string &in id) {
    int v = UI::InputInt(label + "##" + id, value);
    int outV = v < 0 ? 0 : v;
    UI::SameLine();
    if (UI::Button("✕##rm-" + id)) outV = 0;
    return outV;
}

void _RenderStepTimeouts(StepDef@ s, int stepIdx, int tabUid) {
    bool hasBF = s.beforeFrames > 0;
    bool hasBM = s.beforeMs     > 0;
    bool hasAF = s.afterFrames  > 0;
    bool hasAM = s.afterMs      > 0;

    bool anyActive = hasBF || hasBM || hasAF || hasAM;

    UI::Text("Timeouts"); UI::SameLine();
    UI::TextDisabled(anyActive ? "(click ✕ to remove)" : "(none)");

    if (hasBF) { UI::Separator(); s.beforeFrames = _RenderTimeoutInput("Before (frames)", s.beforeFrames, "bf-" + tostring(tabUid) + "-" + tostring(stepIdx)); }
    if (hasBM) { s.beforeMs      = _RenderTimeoutInput("Before (ms)",     s.beforeMs,     "bm-" + tostring(tabUid) + "-" + tostring(stepIdx)); }
    if (hasAF) { s.afterFrames   = _RenderTimeoutInput("After (frames)",  s.afterFrames,  "af-" + tostring(tabUid) + "-" + tostring(stepIdx)); }
    if (hasAM) { s.afterMs       = _RenderTimeoutInput("After (ms)",      s.afterMs,      "am-" + tostring(tabUid) + "-" + tostring(stepIdx)); }

    bool canAdd = !hasBF || !hasBM || !hasAF || !hasAM;
    UI::BeginDisabled(!canAdd);
    UI::SameLine();
    if (UI::BeginCombo("Add timeout##add-" + tostring(tabUid) + "-" + tostring(stepIdx), "Select…")) {
        if (!hasBF && UI::Selectable("Before (frames)", false)) s.beforeFrames = 1;
        if (!hasBM && UI::Selectable("Before (ms)", false))     s.beforeMs     = 50;
        if (!hasAF && UI::Selectable("After (frames)", false))  s.afterFrames  = 1;
        if (!hasAM && UI::Selectable("After (ms)", false))      s.afterMs      = 50;
        UI::EndCombo();
    }
    UI::EndDisabled();

    if (!anyActive) {
        UI::Separator();
        UI::TextDisabled("No timeouts set.");
    }
}

void _PromoteLiteralToParam(EditorTab@ t, uint stepIdx, const string &in argKeyPath, const string &in paramName) {
    if (stepIdx >= t.steps.Length) return;
    StepDef@ s = t.steps[stepIdx];
    if (s.args is null) return;

    array<string> parts = argKeyPath.Split(".");
    Json::Value@ cur = s.args;
    for (uint i = 0; i + 1 < parts.Length; ++i) {
        if (!cur.HasKey(parts[i])) return;
        @cur = cur[parts[i]];
    }
    string last = parts[parts.Length-1];
    if (!cur.HasKey(last)) return;

    if (!t.paramsSpec.HasKey(paramName)) {
        Json::Value d = Json::Object();
        d["type"]="string"; d["default"] = string(cur[last]);
        t.paramsSpec[paramName] = d;
    }
    cur[last] = "$params." + paramName;
}

void _RenderSteps(EditorTab@ t) {
    if (!UI::CollapsingHeader("Steps##steps-"+tostring(t.uid))) return;

    array<int> indents = _ComputeIndentLevels(t);
    const float kIndentPx = 18.0f;

    UI::BeginChild("steps-scroll##"+tostring(t.uid), vec2(0, 0), true);

    for (uint i = 0; i < t.steps.Length; ++i) {
        StepDef@ s = t.steps[i];
        if (s is null) continue;

        UI::PushID(int(i));

        string badge = _ScopeBadge(s.cmd);

        string visibleHdr = "Step " + tostring(i + 1) + "/" + tostring(t.steps.Length);
        string headerId   = visibleHdr + "##step-" + tostring(t.uid) + "-" + tostring(i);

        if (indents[i] > 0) UI::Indent(indents[i] * kIndentPx);

        bool open = UI::CollapsingHeader(headerId);

        UI::SameLine();
        if (badge.Length > 0) { UI::Text(badge); UI::SameLine(); }
        UI::TextDisabled(s.cmd);

        if (open) {
            UI::BeginGroup();
            bool canUp   = i > 0;
            bool canDown = (i + 1) < t.steps.Length;

            if (UI::Button("Delete")) {
                t.steps.RemoveAt(i);
                UI::EndGroup();
                if (indents[i] > 0) UI::Unindent(indents[i] * kIndentPx);
                UI::PopID();
                i--;
                UI::Separator();
                continue;
            }
            UI::SameLine();
            if (UI::Button("Duplicate")) {
                StepDef@ c = StepDef();
                c.cmd = s.cmd;
                @c.args = automata::JsonDeepClone(s.args);
                c.beforeMs     = s.beforeMs;
                c.afterMs      = s.afterMs;
                c.beforeFrames = s.beforeFrames;
                c.afterFrames  = s.afterFrames;
                Tab_InsertStepAt(t, c, i + 1);
            }
            UI::SameLine();
            UI::BeginDisabled(!canUp);
            if (UI::Button("Move Up")) {
                StepDef@ tmp = t.steps[i - 1];
                @t.steps[i - 1] = s;
                @t.steps[i]     = tmp;
            }
            UI::EndDisabled();
            UI::SameLine();
            UI::BeginDisabled(!canDown);
            if (UI::Button("Move Down")) {
                StepDef@ tmp = t.steps[i + 1];
                @t.steps[i + 1] = s;
                @t.steps[i]     = tmp;
            }
            UI::EndDisabled();
            UI::EndGroup();

            UI::Separator();

            s.cmd = UI::InputText("Command", s.cmd);

            _RenderStepTimeouts(s, int(i), t.uid);

            UI::Separator();

            string argsTxt = s.args is null ? "{}" : Json::Write(s.args, true);
            string newArgsTxt = UI::InputTextMultiline(
                "Args (JSON)##args-"+tostring(t.uid)+"-"+tostring(i),
                argsTxt,
                vec2(0, 120),
                UI::InputTextFlags::AllowTabInput
            );
            if (newArgsTxt != argsTxt) {
                Json::Value@ parsed = Json::Parse(newArgsTxt);
                if (parsed !is null) {
                    @s.args = parsed;
                } else {
                    NotifyWarn("Invalid JSON in Args; keeping previous value.");
                }
            }

            UI::TextDisabled("Promote literal to $params.*");
            t.promoteArgPath   = UI::InputText("Arg JSON Path (e.g., material or args.material)##ppath-"+tostring(t.uid), t.promoteArgPath);
            t.promoteParamName = UI::InputText("Param name (e.g., materialId)##pname-"+tostring(t.uid), t.promoteParamName);
            if (UI::Button("Promote##promote-"+tostring(t.uid)+"-"+tostring(i))) {
                string path = t.promoteArgPath;
                if (path.StartsWith("args.")) path = path.SubStr(5);
                if (path.Length > 0 && t.promoteParamName.Length > 0) {
                    _PromoteLiteralToParam(t, i, path, t.promoteParamName);
                }
            }

            UI::Separator();

            Json::Value@ defaults = Json::Object();
            if (t.paramsSpec !is null) {
                array<string>@ keys = t.paramsSpec.GetKeys();
                for (uint k = 0; k < keys.Length; ++k) {
                    string key = keys[k];
                    if (t.paramsSpec[key].HasKey("default")) defaults[key] = t.paramsSpec[key]["default"];
                }
            }
            RunCtx dummy; dummy.defaultOverlay = t.overlay;
            Json::Value@ preview = ResolveArgs(s.args, dummy, defaults);
            UI::BeginChild("preview##" + tostring(t.uid) + "-" + tostring(i), vec2(0, 120), true);
            UI::TextWrapped(Json::Write(preview, true));
            UI::EndChild();
        }

        if (indents[i] > 0) UI::Unindent(indents[i] * kIndentPx);

        UI::Separator();
        UI::PopID();
    }

    if (UI::Button("+ Add Step##addstep-"+tostring(t.uid))) {
        StepDef@ ns = StepDef();
        ns.cmd = "ui_click";
        @ns.args = Json::Object();
        t.steps.InsertLast(ns);
    }

    UI::EndChild();
}


void _RenderTab(EditorTab@ t, int tabIdx) {
    UI::PushID("tab-"+tostring(t.uid));

    string editingPath = (t.editing is null) ? "<new>" : Path::GetFileName(t.editing.sourcePath);
    UI::Text("Title: " + t.name + "    Source: " + editingPath);

    if (UI::Button("Save##save")) _Save(t);
    UI::SameLine();
    if (UI::Button("Run##run")) {
        Json::Value@ rp = Json::Object();
        if (t.paramsSpec !is null) {
            array<string>@ keys = t.paramsSpec.GetKeys();
            for (uint k = 0; k < keys.Length; ++k) {
                string key = keys[k];
                if (t.paramsSpec[key].HasKey("default")) rp[key] = t.paramsSpec[key]["default"];
            }
        }
        FlowDef f;
        f.name = t.name; f.version = t.version; @f.paramsSpec = t.paramsSpec; @f.display = t.display;
        f.display["overlay"] = t.overlay;
        f.sourcePath = (t.editing is null) ? "" : t.editing.sourcePath;
        for (uint i = 0; i < t.steps.Length; ++i) { f.steps.InsertLast(t.steps[i]); }
        StartRun(f, rp);
    }
    UI::SameLine();
    if (UI::Button("Reorder…##reorder")) t.showReorderPanel = !t.showReorderPanel;

    UI::SameLine();
    if (gActive !is null) {
        gActive.ctx.stepMode = UI::Checkbox("Step mode##stepmode", gActive.ctx.stepMode);
        UI::SameLine();
        if (UI::Button("Continue##cont")) gActive.ctx.stepGateOpen = true;
        UI::SameLine();
        UI::Text("Status: " + gActive.statusStr);
    }
    UI::SameLine();
    if (UI::Button("Close Tab##closetab")) {
        gTabs.RemoveAt(tabIdx);
        if (gTabs.Length == 0) {
            gActiveTab = -1;
            gShow = false;
            UI::PopID();
            return;
        } else {
            gActiveTab = Math::Min(tabIdx, int(gTabs.Length) - 1);
            UI::PopID();
            return;
        }
    }

    UI::Separator();

    if (UI::BeginChild("FlowEditorScroll##"+tostring(t.uid), vec2(0, 0), true)) {
        t.name    = UI::InputText("Flow name##fname-"+tostring(t.uid), t.name);
        t.version = UI::InputInt("Version##ver-"+tostring(t.uid), t.version);
        t.overlay = UI::InputInt("Default UI Overlay##ovl-"+tostring(t.uid), t.overlay);

        UI::Separator();
        _RenderParams(t);
        UI::Separator();

        if (t.showReorderPanel) {
            if (UI::CollapsingHeader("Reorder Steps##reorder-"+tostring(t.uid))) {
                if (t.reorderToIndex.Length != t.steps.Length) t.EnsureReorderArray();
                if (UI::BeginTable("reorder-table##"+tostring(t.uid), 4, UI::TableFlags::RowBg | UI::TableFlags::Resizable | UI::TableFlags::ScrollY)) {
                    UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 40.0f);
                    UI::TableSetupColumn("Command", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("Move", UI::TableColumnFlags::WidthFixed, 320.0f);
                    UI::TableSetupColumn("To Index", UI::TableColumnFlags::WidthFixed, 160.0f);
                    UI::TableHeadersRow();

                    for (uint i = 0; i < t.steps.Length; ++i) {
                        UI::TableNextRow();
                        UI::TableNextColumn(); UI::Text(tostring(i+1));
                        UI::TableNextColumn(); UI::Text(t.steps[i] is null ? "<null>" : t.steps[i].cmd);

                        UI::TableNextColumn();
                        if (UI::Button("Up##r"+tostring(i)))    { Tab_MoveStep(t, i, i == 0 ? 0 : i - 1); t.EnsureReorderArray(); UI::EndTable(); UI::EndChild(); UI::PopID(); return; }
                        UI::SameLine();
                        if (UI::Button("Down##r"+tostring(i)))  { Tab_MoveStep(t, i, i + 1 >= t.steps.Length ? t.steps.Length - 1 : i + 1); t.EnsureReorderArray(); UI::EndTable(); UI::EndChild(); UI::PopID(); return; }
                        UI::SameLine();
                        if (UI::Button("Top##r"+tostring(i)))   { Tab_MoveStep(t, i, 0); t.EnsureReorderArray(); UI::EndTable(); UI::EndChild(); UI::PopID(); return; }
                        UI::SameLine();
                        if (UI::Button("Bottom##r"+tostring(i))){ Tab_MoveStep(t, i, t.steps.Length - 1); t.EnsureReorderArray(); UI::EndTable(); UI::EndChild(); UI::PopID(); return; }

                        UI::TableNextColumn();
                        int to = t.reorderToIndex[i];
                        to = UI::InputInt(("##to"+tostring(i)), to);
                        t.reorderToIndex[i] = Math::Clamp(to, 0, int(t.steps.Length) - 1);
                        UI::SameLine();
                        if (UI::Button("Move##to"+tostring(i))) {
                            Tab_MoveStep(t, i, uint(t.reorderToIndex[i]));
                            t.EnsureReorderArray();
                            UI::EndTable();
                            UI::EndChild();
                            UI::PopID();
                            return;
                        }
                    }
                    UI::EndTable();
                }
                if (UI::Button("Close Reorder Panel##close-reorder-"+tostring(t.uid))) t.showReorderPanel = false;
                UI::Separator();
            }
        }

        _RenderSteps(t);
    }
    UI::EndChild();

    UI::PopID();
}

void Render() {
    if (!gShow) return;

    UI::SetNextWindowSize(980, 680, UI::Cond::FirstUseEver);
    if (UI::Begin("Flow Editor", gShow)) {
        if (gTabs.Length == 0) {
            UI::TextDisabled("No flow editor tabs open.");
            if (UI::Button("New Flow")) NewFlow();
            UI::End();
            return;
        }

        if (gActiveTab < 0 || gActiveTab >= int(gTabs.Length)) gActiveTab = 0;

        
        UI::BeginTabBar("automata_FlowEditorTabs");
        for (int i = 0; i < int(gTabs.Length); ++i) {
            string tabLabel = "Flow " + tostring(gTabs[i].uid);

            bool open = UI::BeginTabItem(tabLabel);
            if (open) {
                gActiveTab = i;
                _RenderTab(gTabs[i], i);
                UI::EndTabItem();
            }
        }
        UI::EndTabBar();
    }
    UI::End();
}

void ToggleEditorWindow() { gShow = !gShow; }

}}
