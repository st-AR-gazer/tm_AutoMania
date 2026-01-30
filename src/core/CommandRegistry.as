namespace automata {

funcdef bool CommandFn(FlowRun@ run, Json::Value@ args);

class CommandRegistry {
    dictionary fns;
    dictionary aliases;

    void Register(const string &in name, CommandFn@ fn) {
        @fns[name] = @fn;
    }
    void Alias(const string &in from, const string &in to) { aliases[from] = to; }

    bool Execute(const string &in cmd, FlowRun@ run, Json::Value@ rawArgs) {
        string key = cmd;
        if (aliases.Exists(key)) key = string(aliases[key]);

        if (!fns.Exists(key)) {
            log("Unknown command: " + cmd, LogLevel::Error, 19, "Execute");
            run.ctx.lastError = "Unknown command: " + cmd;
            return false;
        }
        CommandFn@ f = cast<CommandFn@>(fns[key]);
        Json::Value@ args = ResolveArgs(rawArgs, run.ctx, run.params);
        return f(run, args);
    }
}

CommandRegistry@ gCmds;

void InitRegistry() {
    @gCmds = CommandRegistry();

    RegisterUiCommands(gCmds);
    RegisterMeshCommands(gCmds);
    RegisterBatchCommands(gCmds);

    automata::Helpers::IconRotationSave::RegisterSaveIconRotation(gCmds);
    automata::Helpers::IconRotationApply::RegisterApplySavedIconRotation(gCmds);
    automata::Helpers::OpenMeshModeller::RegisterOpenMeshModeller(gCmds);
    automata::Helpers::ExportCurrentBlockVariants::RegisterExportCurrentVariants(gCmds);
    automata::Helpers::VariantsPanel::RegisterVariantsCommands(gCmds);
    automata::Helpers::VariantSkips::RegisterVariantSkipsCleanup(gCmds);
    automata::Helpers::ItemEditorExit::RegisterItemEditorExit(gCmds);
    automata::Helpers::OpenMapEditor::RegisterOpenMapEditor(gCmds);
    automata::Helpers::ExitMeshModeller::RegisterExitMeshModeller(gCmds);
    automata::Helpers::FlowStatus::RegisterFlowStatusCommands(gCmds);
}

}