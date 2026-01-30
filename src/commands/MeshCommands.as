namespace automata {

int _CtxGetInt(FlowRun@ run, const string &in key, int def) {
    if (run is null) return def;
    string s;
    if (run.ctx.GetString(key, s)) {
        s = s.Trim();
        if (s.Length > 0) {
            try { return Text::ParseInt(s); } catch {}
        }
    }
    return def;
}

void _CtxSetInt(FlowRun@ run, const string &in key, int v) {
    if (run is null) return;
    run.ctx.Set(key, tostring(v));
}

bool _TryGetEditorMesh(CGameEditorMesh@ &out em, string &out err) {
    CGameCtnApp@ app = GetApp();
    if (app is null) { err = "App is null."; return false; }
    @em = cast<CGameEditorMesh>(app.Editor);
    if (em is null) { err = "Mesh Modeller is not open (Editor is not CGameEditorMesh)."; return false; }
    return true;
}

string _NormKey(const string &in s) {
    string o = "";
    for (int i = 0; i < s.Length; ++i) {
        string ch = s.SubStr(i, 1);
        if ((ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || (ch >= "0" && ch <= "9")) {
            o += ch.ToLower();
        }
    }
    return o;
}

void _MapToLayerType(const string &in key,
                     CGameEditorMesh::ELayerType &out lt,
                     string &out prettyName)
{
    lt = CGameEditorMesh::ELayerType::AddGeometry; prettyName = "AddGeometry";
    if (key.Length == 0) return;

    if (key == "addgeometry" || key == "geometry" || key == "geom" || key == "geo") { lt = CGameEditorMesh::ELayerType::AddGeometry; prettyName = "AddGeometry"; return; }
    if (key == "subdividesmooth" || key == "subsmooth" || key == "smoothsubdivide") { lt = CGameEditorMesh::ELayerType::SubdivideSmooth; prettyName = "SubdivideSmooth"; return; }
    if (key == "translation" || key == "move" || key == "translate") { lt = CGameEditorMesh::ELayerType::Translation; prettyName = "Translation"; return; }
    if (key == "rotation" || key == "rotate") { lt = CGameEditorMesh::ELayerType::Rotation; prettyName = "Rotation"; return; }
    if (key == "scale" || key == "scaling")   { lt = CGameEditorMesh::ELayerType::Scale; prettyName = "Scale"; return; }
    if (key == "mirror") { lt = CGameEditorMesh::ELayerType::Mirror; prettyName = "Mirror"; return; }
    if (key == "movetoground" || key == "snapground" || key == "ground") { lt = CGameEditorMesh::ELayerType::MoveToGround; prettyName = "MoveToGround"; return; }
    if (key == "extrude") { lt = CGameEditorMesh::ELayerType::Extrude; prettyName = "Extrude"; return; }
    if (key == "subdivide") { lt = CGameEditorMesh::ELayerType::Subdivide; prettyName = "Subdivide"; return; }
    if (key == "chaos") { lt = CGameEditorMesh::ELayerType::Chaos; prettyName = "Chaos"; return; }
    if (key == "smooth") { lt = CGameEditorMesh::ELayerType::Smooth; prettyName = "Smooth"; return; }
    if (key == "bordertransition" || key == "border" || key == "transition") { lt = CGameEditorMesh::ELayerType::BorderTransition; prettyName = "BorderTransition"; return; }
    if (key == "bloctransfo" || key == "blocktransfo" || key == "blocktransform") { lt = CGameEditorMesh::ELayerType::BlocTransfo; prettyName = "BlocTransfo"; return; }
    if (key == "voxels" || key == "voxel") { lt = CGameEditorMesh::ELayerType::Voxels; prettyName = "Voxels"; return; }
    if (key == "triggershape" || key == "trigger") { lt = CGameEditorMesh::ELayerType::TriggerShape; prettyName = "TriggerShape"; return; }
    if (key == "respawnpos" || key == "respawn" || key == "spawn") { lt = CGameEditorMesh::ELayerType::RespawnPos; prettyName = "RespawnPos"; return; }
    if (key == "sector" || key == "sectors") { lt = CGameEditorMesh::ELayerType::Sector; prettyName = "Sector"; return; }
    if (key == "light" || key == "lights") { lt = CGameEditorMesh::ELayerType::Light; prettyName = "Light"; return; }
    if (key == "lightmodel" || key == "lightmdl" || key == "lightprefab") { lt = CGameEditorMesh::ELayerType::LightModel; prettyName = "LightModel"; return; }
    if (key == "watershape" || key == "water") { lt = CGameEditorMesh::ELayerType::WaterShape; prettyName = "WaterShape"; return; }
    if (key == "none") { lt = CGameEditorMesh::ELayerType::None; prettyName = "None"; return; }
}

bool Cmd_OpenItemEditor(FlowRun@ run, Json::Value@ args) {    
    string blockName = "";
    if (args !is null) {
        if (args.HasKey("block")) blockName = string(args["block"]);
        else if (args.HasKey("name")) blockName = string(args["name"]);
    }
    if (blockName.Length == 0) {
        run.ctx.lastError = "open_item_editor: missing 'block' (e.g. \"$ctx.blockName\").";
        return false;
    }

    string mode = "block-to-block";
    if (args !is null && args.HasKey("mode")) mode = string(args["mode"]);

    string impl = "epp";
    if (args !is null && args.HasKey("impl")) impl = string(args["impl"]).ToLower();

    bool allowFallback = true;
    if (args !is null && args.HasKey("fallback")) allowFallback = bool(args["fallback"]);

    bool ok = false;
    string errPrimary = "", errSecondary = "";

    if (impl == "mouse") {
        ok = automata::Helpers::Cmd_OpenItemEditor_MouseMovement::OpenItemEditor(mode, blockName, errPrimary);
        if (!ok && allowFallback) {
            ok = automata::Helpers::Cmd_OpenItemEditor_EditorPlusPlus::OpenItemEditor(mode, blockName, errSecondary);
        }
    } else {
        ok = automata::Helpers::Cmd_OpenItemEditor_EditorPlusPlus::OpenItemEditor(mode, blockName, errPrimary);
        if (!ok && allowFallback) {
            ok = automata::Helpers::Cmd_OpenItemEditor_MouseMovement::OpenItemEditor(mode, blockName, errSecondary);
        }
    }

    if (!ok) {
        string combined = errPrimary;
        if (allowFallback) {
            if (combined.Length > 0 && errSecondary.Length > 0) combined += " | fallback: " + errSecondary;
            else if (combined.Length == 0) combined = errSecondary;
        }
        run.ctx.lastError = "open_item_editor(" + impl + "): " + (combined.Length > 0 ? combined : "unknown error");
        return false;
    }

    run.ctx.Set("openItemEditorImpl", impl);

    string canonical = automata::Helpers::SaveFile::GetCanonicalForBlockName(blockName);
    if (canonical.Length > 0) {
        string canonicalTail = automata::Helpers::SaveFile::TailFromCanonical(canonical);
        run.ctx.Set("blockCanonical", canonical);
        run.ctx.Set("canonicalTail", canonicalTail);
        log("open_item_editor: canonical='" + canonical + "' canonicalTail='" + canonicalTail + "'", LogLevel::Debug, 121, "Cmd_OpenItemEditor");

    } else {
        log("open_item_editor: canonical not found for '" + blockName + "'", LogLevel::Warn, 124, "Cmd_OpenItemEditor");
    }

    return true;
}

bool Cmd_SetBlockByName(FlowRun@ run, Json::Value@ args) {
    if (args is null || !args.HasKey("block")) { run.ctx.lastError = "set_block_by_name: missing 'block'"; return false; }
    string blk = string(args["block"]);
    string err;
    if (!Helpers::Blocks::SetCurrentByName(blk, err)) {
        run.ctx.lastError = err;
        return false;
    }
    run.ctx.Set("blockName", Helpers::Blocks::GetCurrentName());
    return true;
}

bool Cmd_RebuildBlockIndex(FlowRun@ run, Json::Value@ args) {
    string err;
    if (!Helpers::Blocks::RebuildIndex(err)) {
        run.ctx.lastError = err;
        return false;
    }
    return true;
}

bool Cmd_SaveIconRotation(FlowRun@ run, Json::Value@ args) {
    return automata::Helpers::IconRotationSave::Cmd_SaveIconRotation(run, args);
}

bool Cmd_ApplySavedIconRotation(FlowRun@ run, Json::Value@ args) {
    return automata::Helpers::IconRotationApply::Cmd_ApplySavedIconRotation(run, args);
}

bool Cmd_OpenMeshModeller(FlowRun@ run, Json::Value@ args) {
    bool ok = automata::Helpers::OpenMeshModeller::Cmd_OpenMeshModeller(run, args);
    if (!ok || run is null) return ok;

    string opened = "";
    string skipped = "";
    bool hasOpened  = run.ctx.GetString("meshModellerOpened", opened);
    bool hasSkipped = run.ctx.GetString("meshModellerSkipped", skipped);

    bool isSkipped = hasSkipped && skipped == "1";
    bool isOpened  = hasOpened && opened == "1";

    bool shouldCountAsOpen = (!isSkipped) && (isOpened || (!hasOpened && !hasSkipped));

    if (shouldCountAsOpen) {
        int depth = _CtxGetInt(run, "mmOpenDepth", 0);
        _CtxSetInt(run, "mmOpenDepth", depth + 1);
    }

    return ok;
}

bool Cmd_CreateNewLayer(FlowRun@ run, Json::Value@ args) {
    CGameEditorMesh@ mm; string err;
    if (!_TryGetEditorMesh(mm, err)) { run.ctx.lastError = "create_new_layer: " + err; return false; }

    string rawType = "";
    if (args !is null) {
        if (args.HasKey("type"))           rawType = string(args["type"]);
        else if (args.HasKey("layerType")) rawType = string(args["layerType"]);
        else if (args.HasKey("kind"))      rawType = string(args["kind"]);
    }
    string key = _NormKey(rawType);
    CGameEditorMesh::ELayerType lt; string nice;
    _MapToLayerType(key, lt, nice);

    if (rawType.Length > 0 && nice == "AddGeometry" && key != "" && key != "addgeometry" && key != "geometry" && key != "geom" && key != "geo") {
        log("create_new_layer: unknown type '" + rawType + "' — defaulting to AddGeometry.", LogLevel::Warn, 196, "Cmd_CreateNewLayer");

    }

    mm.Layers_AddLayer(lt);
    yield();

    run.ctx.Set("lastLayerType", nice);
    run.ctx.Set("lastLayerTypeKey", key);

    log("create_new_layer: added layer type '" + nice + "'.", LogLevel::Info, 206, "Cmd_CreateNewLayer");
    return true;
}

bool Cmd_RenameLayerIndex(FlowRun@ run, Json::Value@ args) {
    if (args is null || !args.HasKey("index") || !args.HasKey("name")) {
        run.ctx.lastError = "rename_layer_index requires index/name";
        return false;
    }
    int idx = int(args["index"]);
    string nm = string(args["name"]);
    
    return true;
}

bool Cmd_SelectLayerIndex(FlowRun@ run, Json::Value@ args) {
    if (args is null || !args.HasKey("index")) { run.ctx.lastError="select_layer_index requires index"; return false; }
    int idx = int(args["index"]);
    
    return true;
}

bool Cmd_DeleteFacesInSelectedLayer(FlowRun@ run, Json::Value@ args) {
    return true;
}

bool Cmd_SelectMaterialByName(FlowRun@ run, Json::Value@ args) {
    if (args is null || !args.HasKey("material")) { run.ctx.lastError="select_material_by_name requires material"; return false; }
    string mat = string(args["material"]);
    
    run.ctx.Set("materialId", mat);
    return true;
}

bool Cmd_SetMaterial(FlowRun@ run, Json::Value@ args) {
    if (args is null || !args.HasKey("material")) { run.ctx.lastError="set_material requires material"; return false; }
    string mat = string(args["material"]);
    
    return true;
}

bool Cmd_CutSelection(FlowRun@ run, Json::Value@ args) { return true; }
bool Cmd_SetIcon(FlowRun@ run, Json::Value@ args) { return true; }
bool Cmd_SaveFile(FlowRun@ run, Json::Value@ args) { return automata::Helpers::SaveFile::Cmd_SaveFile(run, args); }

void RegisterMeshCommands(CommandRegistry@ R) {
    R.Register("open_item_editor", CommandFn(Cmd_OpenItemEditor));
    R.Register("set_block_by_name", CommandFn(Cmd_SetBlockByName));
    R.Register("rebuild_block_index", CommandFn(Cmd_RebuildBlockIndex));
    R.Register("save_icon_rotation", CommandFn(Cmd_SaveIconRotation));
    R.Register("apply_saved_icon_rotation", CommandFn(Cmd_ApplySavedIconRotation));
    R.Register("open_mesh_modeller", CommandFn(Cmd_OpenMeshModeller));
    R.Register("create_new_layer", CommandFn(Cmd_CreateNewLayer));
    R.Register("rename_layer_index", CommandFn(Cmd_RenameLayerIndex));
    R.Register("select_layer_index", CommandFn(Cmd_SelectLayerIndex));
    R.Register("delete_all_faces_in_selected_layer", CommandFn(Cmd_DeleteFacesInSelectedLayer));
    R.Register("select_material_by_name", CommandFn(Cmd_SelectMaterialByName));
    R.Register("set_material", CommandFn(Cmd_SetMaterial));
    R.Register("cut_selection", CommandFn(Cmd_CutSelection));
    R.Register("set_icon", CommandFn(Cmd_SetIcon));
    R.Register("save_file", CommandFn(Cmd_SaveFile));
}

}
