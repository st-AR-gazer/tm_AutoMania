namespace automata { namespace Helpers { namespace IconRotationSave {

bool _TryReadFromItemEditor(int &out quarter, string &out blockName) {
    CGameCtnApp@ app = GetApp();
    if (app is null) return false;

    CGameEditorItem@ editor = cast<CGameEditorItem>(app.Editor);
    if (editor is null) return false;

    CGameItemModel@ im = editor.ItemModel;
    if (im is null) return false;

    CGameBlockItem@ biItem = cast<CGameBlockItem>(editor.ItemModel.EntityModelEdition);
    if (biItem is null) return false;

    CGameCtnBlockInfoClassic@ bic = cast<CGameCtnBlockInfoClassic>(im.EntityModel);
    if (bic !is null) {
        quarter   = int(bic.IconQuarterRotationY);
        blockName = biItem.ArchetypeBlockInfoId_GameBox.GetName();
        return true;
    }

    CGameCtnBlockInfo@ bi = cast<CGameCtnBlockInfo>(im.EntityModel);
    if (bi !is null) {
        quarter   = int(bi.IconQuarterRotationY);
        blockName = bi.Name;
        return true;
    }

    return false;
}

bool Cmd_SaveIconRotation(FlowRun@ run, Json::Value@ args) {
    CGameCtnBlockInfo@ cur;
    string curCanon;
    if (Helpers::Blocks::GetCurrent(cur, curCanon) && cur !is null) {
        string rot = tostring(cur.IconQuarterRotationY);
        run.ctx.Set("savedIconQuarterRotationY", rot);

        string chosenName = curCanon;
        if (chosenName.Length == 0) chosenName = tostring(cur.Name);

        run.ctx.Set("savedBlockName", chosenName);
        run.ctx.Set("blockName", chosenName);

        log("Saved icon rotation (cached block) '" + chosenName + "' (cur.Name='" + cur.Name + "'): " + rot, LogLevel::Info, 46, "Cmd_SaveIconRotation");
        return true;
    }

    int q;
    string nm;
    if (_TryReadFromItemEditor(q, nm)) {
        run.ctx.Set("savedIconQuarterRotationY", tostring(q));
        run.ctx.Set("savedBlockName", nm);

        string existing;
        bool haveExisting = run.ctx.GetString("blockName", existing) && existing.Length > 0;
        if (!haveExisting) run.ctx.Set("blockName", nm);

        log("Saved icon rotation (Item Editor) '" + nm + "': " + tostring(q)
            + (haveExisting ? " (kept ctx.blockName='" + existing + "')" : " (set ctx.blockName)"), LogLevel::Info, 60, "Cmd_SaveIconRotation");


        return true;
    }

    run.ctx.lastError = "save_icon_rotation: neither a cached block nor an Item Editor block is available.";
    return false;
}

void RegisterSaveIconRotation(CommandRegistry@ R) {
    R.Register("save_icon_rotation", CommandFn(Cmd_SaveIconRotation));
}

}}}