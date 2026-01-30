namespace automata { namespace Helpers { namespace ExportCurrentBlockVariants {

const uint   kOverlayItemEditor = 2;
const string kBaseProps         = "0/4/1/0/1";
const string kBtnAddVariant     = kBaseProps + "/10/2";
const int    kFirstRowIdx       = 11;
const int    kMaxRowsScan       = 320;
const string kRowLabelRel       = "6/4";
const string kRowDeleteRel      = "2";

string _Sanitize(const string &in s) {
    string outS = "";
    for (int i = 0; i < s.Length; ++i) {
        string ch = s.SubStr(i, 1);
        if ((ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || (ch >= "0" && ch <= "9") || ch == "_" || ch == "-") {
            outS += ch;
        } else if (ch == " ") {
            outS += "_";
        } else {
            outS += "-";
        }
    }
    return outS.Length == 0 ? "block" : outS;
}

string _StripColorPrefix(const string &in s) {
    if (s.Length >= 4 && s.SubStr(0, 1) == "$") return s.SubStr(4);
    return s;
}

string _ExtractVariantKey(const string &in raw) {
    string s = _StripColorPrefix(raw).Trim();
    int sp = s.IndexOf(" ");
    return (sp >= 0) ? s.SubStr(0, sp) : s;
}

CControlBase@ _ResolveRow(uint rowIdx) {
    return UiNav::ResolvePath(kBaseProps + "/" + tostring(rowIdx), kOverlayItemEditor);
}

string _ReadRowLabel(uint rowIdx) {
    CControlBase@ row = _ResolveRow(rowIdx);
    if (row is null) return "";
    CControlBase@ lab = UiNav::ResolvePath(kRowLabelRel, kOverlayItemEditor, row);
    return UiNav::ReadText(lab);
}

bool _DeleteRow(uint rowIdx) {
    CControlBase@ row = _ResolveRow(rowIdx);
    if (row is null) return false;
    CControlBase@ btn = UiNav::ResolvePath(kRowDeleteRel, kOverlayItemEditor, row);
    CControlButton@ b = cast<CControlButton>(btn);
    if (b is null) return false;
    b.OnAction();
    yield();
    return true;
}

bool _ClickAddRow() { return UiNav::ClickPath(kBtnAddVariant, kOverlayItemEditor); }
void _EnsurePropsPanel() { UiNav::WaitForPath(kBaseProps, kOverlayItemEditor, 4000, 33); }

int _ScanRows(dictionary &inout uniqueKeys) {
    int added = 0;
    for (int r = kFirstRowIdx; r < kFirstRowIdx + kMaxRowsScan; ++r) {
        string txt = _ReadRowLabel(uint(r));
        if (txt.Length == 0) continue;
        string key = _ExtractVariantKey(txt);
        if (key.Length == 0) continue;
        if (!uniqueKeys.Exists(key)) { uniqueKeys[key] = true; added++; }
    }
    return added;
}

void _DiscoverAndDedupVariants(dictionary &out uniqueKeys) {
    uniqueKeys.DeleteAll();
    _EnsurePropsPanel();

    _ScanRows(uniqueKeys);
    for (int cycle = 0; cycle < 100; ++cycle) {
        if (!_ClickAddRow()) break;
        yield(2);
        array<string> before = uniqueKeys.GetKeys();
        int inc = _ScanRows(uniqueKeys);
        array<string> after = uniqueKeys.GetKeys();
        if (inc == 0 && after.Length == before.Length) break;
    }

    dictionary seen; seen.DeleteAll();
    for (int r = kFirstRowIdx + kMaxRowsScan - 1; r >= kFirstRowIdx; --r) {
        string txt = _ReadRowLabel(uint(r));
        if (txt.Length == 0) continue;
        string key = _ExtractVariantKey(txt);
        if (key.Length == 0) continue;
        if (seen.Exists(key)) _DeleteRow(uint(r));
        else seen[key] = true;
    }
}

bool _ResolveCurrentBlockName(RunCtx &in ctx, string &out canonName) {
    if (ctx.GetString("blockName", canonName) && canonName.Length > 0) return true;

    CGameCtnApp@ app = GetApp();
    CGameEditorItem@ ed = cast<CGameEditorItem>(app.Editor);
    if (ed is null) return false;

    CGameItemModel@ im = ed.ItemModel;
    if (im is null) return false;

    CGameCtnBlockInfoClassic@ bic = cast<CGameCtnBlockInfoClassic>(im.EntityModel);
    if (bic is null) return false;

    canonName = bic.Name;
    return canonName.Length > 0;
}

bool _TouchVariantMesh(FlowRun@ run, const string &in variantKeyRaw) {
    string blk = "";
    _ResolveCurrentBlockName(run.ctx, blk);
    if (blk.Length > 0) run.ctx.Set("blockName", blk);

    string variantKey = variantKeyRaw.Trim();
    if (variantKey.Length == 0) return true;

    Json::Value@ a = Json::Object();
    a["mode"] = "block-to-block";
    a["variantKey"] = variantKey;
    a["prefer"] = "auto";
    a["okOnSkip"] = true;
    a["skipIfKnownCrash"] = true;

    if (blk.Length > 0) a["blockName"] = blk;

    bool ok = automata::gCmds.Execute("open_mesh_modeller", run, a);
    if (!ok) {
        log("export_current_block_variants: open_mesh_modeller failed for variant '" + variantKey + "': " + run.ctx.lastError, LogLevel::Warn, 135, "_TouchVariantMesh");

        return false;
    }

    string opened = "";
    string skipped = "";
    bool hasOpened  = run.ctx.GetString("meshModellerOpened", opened);
    bool hasSkipped = run.ctx.GetString("meshModellerSkipped", skipped);

    bool isSkipped = hasSkipped && skipped == "1";
    bool isOpened  = hasOpened && opened == "1";

    if (!isSkipped && (isOpened || (!hasOpened && !hasSkipped))) {
        yield(6);

        Json::Value@ ea = Json::Object();
        ea["action"] = "yes";
        ea["timeoutMs"] = 6000;
        ea["times"] = 2;

        automata::gCmds.Execute("exit_mesh_modeller_keep", run, ea);
        yield(2);
    }

    return true;
}

bool _SaveUsingCtxPath(FlowRun@ run, const string &in saveRoot, const string &in blockName) {
    string invRelDir;
    bool have = run.ctx.GetString("inventoryRelDir", invRelDir) && invRelDir.Length > 0;

    string relDir = saveRoot.Length > 0 ? saveRoot : "Exported";
    if (have) relDir = relDir + "/" + invRelDir;

    CGameCtnApp@ app = GetApp();
    CGameEditorItem@ editorItem = cast<CGameEditorItem>(app.Editor);
    if (editorItem is null) { run.ctx.lastError = "export_current_block_variants: Item Editor is not open."; return false; }

    string relBaseNoExt = relDir + "/" + _Sanitize(blockName);
    string relPath = relBaseNoExt + ".Block.Gbx";
    string absPath = IO::FromUserGameFolder("Blocks/" + relPath);

    string absDir = IO::FromUserGameFolder("Blocks/" + relDir);
    if (!IO::FolderExists(absDir)) IO::CreateFolder(absDir, true);

    int idx = 1;
    while (IO::FileExists(absPath) && idx < 10000) {
        relPath = relBaseNoExt + "-" + tostring(idx) + ".Block.Gbx";
        absPath = IO::FromUserGameFolder("Blocks/" + relPath);
        idx++;
    }

    log("Export: saving to Blocks/" + relPath, LogLevel::Info, 188, "_SaveUsingCtxPath");
    editorItem.FileSaveAs();
    yield(3);
    app.BasicDialogs.String = relPath;
    yield();
    app.BasicDialogs.DialogSaveAs_OnValidate();
    yield();
    app.BasicDialogs.DialogSaveAs_OnValidate();
    yield();

    run.ctx.Set("lastSavedRel", relPath);
    run.ctx.Set("lastSavedAbs", absPath);
    return true;
}

bool Cmd_ExportCurrentBlockVariants(FlowRun@ run, Json::Value@ args) {
    string saveRoot = "Exported";
    if (args !is null && args.HasKey("saveRoot")) saveRoot = _Sanitize(string(args["saveRoot"]));
    
    CGameCtnApp@ app = GetApp();
    if (cast<CGameEditorItem>(app.Editor) is null) {
        run.ctx.lastError = "export_current_block_variants: Item Editor is not open.";
        return false;
    }

    dictionary variants;
    _DiscoverAndDedupVariants(variants);

    array<string> keys = variants.GetKeys();
    for (uint i = 0; i < keys.Length; ++i) {
        string key = keys[i];
        if (key.Length == 0) continue;
        _TouchVariantMesh(run, key);
    }
    
    string canonName;
    if (!_ResolveCurrentBlockName(run.ctx, canonName)) canonName = "UnnamedBlock";
    if (!_SaveUsingCtxPath(run, saveRoot, canonName)) return false;

    return true;
}

void RegisterExportCurrentVariants(CommandRegistry@ R) {
    R.Register("export_current_block_variants", CommandFn(Cmd_ExportCurrentBlockVariants));
}

}}}