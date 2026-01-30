namespace automata {

bool gShowMain = true;
string gSearch = "";
string gFlowsDir = IO::FromStorageFolder("flows/");
int gSelectedFlow = -1;

void ToggleMainWindow() { gShowMain = !gShowMain; }

void Render_MainWindow() {
    if (!gShowMain) return;
    UI::SetNextWindowSize(800, 520, UI::Cond::FirstUseEver);
    if (UI::Begin("AutoMania — Flows", gShowMain)) {
        UI::Text("Flow directory: " + gFlowsDir);
        UI::SameLine();
        if (UI::Button("Reload")) ReloadFlows();

        UI::Separator();

        UI::Text("Search:");
        UI::SameLine();
        UI::SetNextItemWidth(300);
        gSearch = UI::InputText("##search", gSearch);
        UI::SameLine();
        if (UI::Button("Create New Flow")) {
            UI_FlowEditor::NewFlow();
        }

        UI::Separator();

        if (UI::BeginTable("flows-table", 3, UI::TableFlags::RowBg | UI::TableFlags::Resizable | UI::TableFlags::ScrollY)) {
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Section", UI::TableColumnFlags::WidthFixed, 160.0f);
            UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed, 260.0f);
            UI::TableHeadersRow();

            for (uint i = 0; i < gFlows.Length; ++i) {
                auto f = gFlows[i];
                if (gSearch.Length > 0 && f.name.ToLower().IndexOf(gSearch.ToLower()) < 0) continue;

                UI::TableNextRow();
                UI::TableNextColumn();
                if (UI::Selectable(f.name, int(i) == gSelectedFlow)) gSelectedFlow = i;

                UI::TableNextColumn();
                string sect = (f.display !is null && f.display.HasKey("section")) ? string(f.display["section"]) : "";
                UI::Text(sect);

                UI::TableNextColumn();
                if (gActive !is null && gActive.flow is f && gActive.status == FlowStatus::Running) {
                    if (UI::Button("Pause##" + tostring(i))) PauseOrResume();
                    UI::SameLine();
                    if (UI::Button("Stop##" + tostring(i))) StopRun();
                } else if (gActive !is null && gActive.flow is f && gActive.status == FlowStatus::Paused) {
                    if (UI::Button("Resume##" + tostring(i))) PauseOrResume();
                    UI::SameLine();
                    if (UI::Button("Stop##" + tostring(i))) StopRun();
                } else {
                    if (UI::Button("Run##" + tostring(i))) {
                        Json::Value rp = Json::Object();
                        if (f.paramsSpec !is null) {
                            array<string>@ keys = f.paramsSpec.GetKeys();
                            for (uint k = 0; k < keys.Length; ++k) {
                                string key = keys[k];
                                if (f.paramsSpec[key].HasKey("default")) rp[key] = f.paramsSpec[key]["default"];
                            }
                        }
                        StartRun(f, rp);
                    }
                }
                UI::SameLine();
                if (UI::Button("Edit##" + tostring(i))) UI_FlowEditor::OpenFlow(f);
                UI::SameLine();
                if (UI::Button("Delete##" + tostring(i))) {
                    if (IO::FileExists(f.sourcePath)) IO::Delete(f.sourcePath);
                    ReloadFlows();
                }
            }
            UI::EndTable();
        }

        UI::Separator();
        if (gActive !is null) {
            string label = "Status: ";
            if (gActive.status == FlowStatus::Running) label += "Running";
            else if (gActive.status == FlowStatus::Paused) label += "Paused";
            else if (gActive.status == FlowStatus::Done) label += "Done";
            else if (gActive.status == FlowStatus::Error) label += "Error";
            UI::Text(label + " — " + gActive.statusStr);

            UI::SameLine();
            gActive.ctx.stepMode = UI::Checkbox("Step mode", gActive.ctx.stepMode);
            UI::SameLine();
            if (UI::Button("Continue")) gActive.ctx.stepGateOpen = true;
        }
    }
    UI::End();
}

}
