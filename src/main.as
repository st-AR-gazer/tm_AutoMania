void Main() {
    automata::InitRegistry();
    automata::ReloadFlows();

    automata::Helpers::CrashWatch::OnPluginStartupRecovery();

    automata::AutoStart::Begin();

    log("AutoMania initialized.", LogLevel::Info, 9, "Main");
}

void RenderInterface() {
    automata::Render_MainWindow();
    automata::UI_FlowEditor::Render();

    UiNav::DevUI::Render();
}

void RenderMenu() {
    if (UI::MenuItem("AutoMania", "", automata::gShowMain)) {
        automata::ToggleMainWindow();
    }
}
