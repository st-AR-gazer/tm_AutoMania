namespace automata { namespace Helpers { namespace SaveFile {

string _SanitizeSuffixForFile(const string &in nm) {
    string outS = "";
    for (int i = 0; i < nm.Length; ++i) {
        string ch = nm.SubStr(i, 1);
        if ((ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z")
         || (ch >= "0" && ch <= "9") || ch == "_" || ch == "-" || ch == ".") outS += ch;
        else if (ch == " ") outS += "_";
        else outS += "-";
    }
    return outS;
}

string JoinWithSlash(const array<string> &in parts) {
    string outS = "";
    for (uint i = 0; i < parts.Length; ++i) {
        string p = parts[i];
        if (p.Length == 0) continue;
        if (outS.Length > 0) outS += "/";
        outS += p;
    }
    return outS;
}

string TrimSlashes(const string &in s) {
    string r = s;
    while (r.StartsWith("/") || r.StartsWith("\\")) r = r.SubStr(1);
    while (r.EndsWith("/")  || r.EndsWith("\\"))  r = r.SubStr(0, r.Length-1);
    return r;
}

string _NormalizeRel(const string &in raw) {
    string s = raw;
    s.Replace("\\", "/");
    while (s.StartsWith("/")) s = s.SubStr(1);
    while (s.EndsWith("/"))   s = s.SubStr(0, s.Length - 1);
    return s;
}

string _JoinRel(const string &in a, const string &in b) {
    if (a.Length == 0) return _NormalizeRel(b);
    if (b.Length == 0) return _NormalizeRel(a);
    string A = _NormalizeRel(a);
    string B = _NormalizeRel(b);
    return A + "/" + B;
}

void _EnsureFolderUnderBlocks(const string &in relFolder) {
    string base = IO::FromUserGameFolder("Blocks");
    string acc  = base;
    array<string> parts = _NormalizeRel(relFolder).Split("/");
    for (uint i = 0; i < parts.Length; ++i) {
        string p = parts[i];
        if (p.Length == 0) continue;
        acc = acc + "/" + p;
        if (!IO::FolderExists(acc)) IO::CreateFolder(acc);
    }
}

string _LeafFromCanonical(const string &in canonical) {
    string c = canonical;
    c.Replace("\\", "/");
    while (c.StartsWith("/")) c = c.SubStr(1);
    while (c.EndsWith("/"))   c = c.SubStr(0, c.Length - 1);
    int k = c.LastIndexOf("/");
    if (k < 0) return c;
    return c.SubStr(k + 1);
}

string TailFromCanonical(const string &in canonical) {
    string c = canonical;
    c.Replace("\\", "/");
    while (c.StartsWith("/")) c = c.SubStr(1);
    while (c.EndsWith("/"))   c = c.SubStr(0, c.Length - 1);
    int k = c.LastIndexOf("/");
    if (k <= 0) return "";
    return c.SubStr(0, k);
}

string GetCanonicalForBlockName(const string &in rawName) {
    CGameCtnBlockInfo@ info; string canonical; string err;
    string clean = Text::StripFormatCodes(rawName).Trim();
    if (automata::Helpers::Blocks::TryFindBlockInfoByName(clean, info, canonical, err)) {
        return canonical;
    }
    return "";
}

string _StripCustomBlockSuffix(const string &in nm) {
    string low = nm.ToLower();
    string sfx = "_customblock";
    if (low.EndsWith(sfx) && nm.Length >= sfx.Length) {
        return nm.SubStr(0, nm.Length - sfx.Length);
    }
    return nm;
}

string _DropDuplicatedBrandFromTail(const string &in prefix, const string &in tail) {
    string pl = _NormalizeRel(prefix).ToLower();
    string tl = _NormalizeRel(tail);
    string tll = tl.ToLower();
    if (pl.EndsWith("/nadeo")) {
        if (tll == "nadeo") return "";
        if (tll.StartsWith("nadeo/")) return tl.SubStr(6); 
    } else if (pl.EndsWith("/custom")) {
        if (tll == "custom") return "";
        if (tll.StartsWith("custom/")) return tl.SubStr(7); 
    }
    return tl;
}

string _NextNonClobberingRelBaseUnderBlocks_NoExt(const string &in relFolder, const string &in baseNoExt) {
    string folder = _NormalizeRel(relFolder);
    string absB   = IO::FromUserGameFolder("Blocks/" + folder + "/" + baseNoExt + ".Block.Gbx");
    string absI   = IO::FromUserGameFolder("Blocks/" + folder + "/" + baseNoExt + ".Item.Gbx");
    int idx = 1;
    while (IO::FileExists(absB) || IO::FileExists(absI)) {
        string cand = baseNoExt + "-" + tostring(idx);
        absB = IO::FromUserGameFolder("Blocks/" + folder + "/" + cand + ".Block.Gbx");
        absI = IO::FromUserGameFolder("Blocks/" + folder + "/" + cand + ".Item.Gbx");
        if (!IO::FileExists(absB) && !IO::FileExists(absI)) {
            return folder + "/" + cand;
        }
        idx++;
        if (idx > 10000) break;
    }
    return folder + "/" + baseNoExt;
}

string _MaybeStripLeaf(const string &in pathIn, const string &in leaf) {
    string invNorm = _NormalizeRel(pathIn);
    string normLeaf = _NormalizeRel(leaf);
    if (invNorm.EndsWith("/" + normLeaf)) {
        invNorm = invNorm.SubStr(0, invNorm.Length - (1 + normLeaf.Length));
    }
    return invNorm;
}

void _SelectInventoryNoLeafAndLeaf(FlowRun@ run, Json::Value@ args,
                                   const string &in rawSrcName,
                                   string &out invNoLeaf,
                                   string &out leafName,
                                   string &out invSource,
                                   string &out canonicalUsed)
{
    invNoLeaf = ""; invSource = ""; canonicalUsed = "";

    string srcName = Text::StripFormatCodes(rawSrcName).Trim();

    string canonical = GetCanonicalForBlockName(srcName);
    canonicalUsed = canonical;
    leafName = canonical.Length > 0 ? _LeafFromCanonical(canonical) : srcName;

    string invPath = Helpers::Args::ReadFirstStr(args, {"inventoryPath", "invPath", "inventoryTail", "inventoryRelDir"}, "");
    if (invPath.Length > 0) {
        invNoLeaf = _MaybeStripLeaf(invPath, leafName);
        invSource = "args";
        return;
    }
    
    string tmp;
    if (run.ctx.GetString("inventoryPath", tmp) && tmp.Length > 0) {
        invNoLeaf = _MaybeStripLeaf(tmp, leafName);
        invSource = "ctx.inventoryPath"; return;
    }
    if (run.ctx.GetString("invPath", tmp) && tmp.Length > 0) {
        invNoLeaf = _MaybeStripLeaf(tmp, leafName);
        invSource = "ctx.invPath"; return;
    }
    if (run.ctx.GetString("inventoryTail", tmp) && tmp.Length > 0) {
        invNoLeaf = _MaybeStripLeaf(tmp, leafName);
        invSource = "ctx.inventoryTail"; return;
    }
    if (run.ctx.GetString("inventoryRelDir", tmp) && tmp.Length > 0) {
        invNoLeaf = _NormalizeRel(tmp);
        invSource = "ctx.inventoryRelDir"; return;
    }
    if (run.ctx.GetString("canonicalTail", tmp) && tmp.Length > 0) {
        invNoLeaf = _NormalizeRel(tmp);
        invSource = "ctx.canonicalTail"; return;
    }
    
    if (canonical.Length > 0) {
        string folderTail; string baseLeaf;
        if (SavePaths::ComputeTailFromCanonical(canonical, true, false, folderTail, baseLeaf)) {
            invNoLeaf = _NormalizeRel(folderTail);
            invSource = "fallback.canonical";
            return;
        }
        string t = TailFromCanonical(canonical);
        if (t.Length > 0) {
            invNoLeaf = _NormalizeRel(t);
            invSource = "fallback.tailFromCanonical";
            return;
        }
    }

    invNoLeaf = "";
    invSource = "none";
}

namespace SavePaths {
    bool ComputeTailFromCanonical(
        const string &in canonical,
        bool includeBrandRoot,
        bool includeCustomRoot,
        string &out folderTail,
        string &out baseName)
    {
        folderTail = ""; baseName = "";
        if (canonical.Length == 0) return false;

        array<string> parts = canonical.Split("/");
        if (parts.Length == 0) { baseName = canonical; return true; }

        baseName = parts[parts.Length - 1];
        array<string> folders;
        for (uint i = 0; i + 1 < parts.Length; ++i) folders.InsertLast(parts[i]);

        if (folders.Length > 0) {
            string brand = folders[0].ToLower();
            bool keepBrand = includeBrandRoot;
            if (brand == "custom" && !includeCustomRoot) keepBrand = false;
            if (!keepBrand) {
                array<string> tmp;
                for (uint j = 1; j < folders.Length; ++j) tmp.InsertLast(folders[j]);
                folders = tmp;
            }
        }
        folderTail = JoinWithSlash(folders);
        return true;
    }

    bool TryGetCanonicalForName(const string &in nm, string &out canonical) {
        CGameCtnBlockInfo@ info; string canon; string err;
        string clean = Text::StripFormatCodes(nm).Trim();
        if (!automata::Helpers::Blocks::TryFindBlockInfoByName(clean, info, canon, err)) return false;
        canonical = canon;
        return true;
    }
}

bool Cmd_SaveFile(FlowRun@ run, Json::Value@ args) {
    
    run.ctx.Set("skippedExisting", "0");

    CGameCtnApp@ app = GetApp();
    if (app is null) { run.ctx.lastError = "save_file: App is null."; return false; }

    
    string scope = "item_editor";
    if (args !is null && args.HasKey("scope")) scope = string(args["scope"]).ToLower().Trim();

    CGameEditorItem@ editorItem = cast<CGameEditorItem>(app.Editor);
    if (scope == "item_editor" && editorItem is null) {
        run.ctx.lastError = "save_file: Item Editor is not open (scope=item_editor).";
        return false;
    } else if (scope != "item_editor") {
        run.ctx.lastError = "save_file: unsupported scope '" + scope + "' (supported: item_editor).";
        return false;
    }
    
    string ctxBlockName = "";
    run.ctx.GetString("blockName", ctxBlockName);

    CGameCtnBlockInfo@ curInfo = null;
    string curCanon = "";
    bool haveCur = automata::Helpers::Blocks::GetCurrent(curInfo, curCanon);
    
    string invHint = "";
    if (args !is null) {
        invHint = Helpers::Args::ReadFirstStr(args, {"inventoryRelDir", "inventoryPath", "invPath", "inventoryTail"}, "");
    }
    if (invHint.Length == 0) {
        string t;
        if (run.ctx.GetString("inventoryRelDir", t)) invHint = t;
    }
    invHint = _NormalizeRel(invHint);

    bool preferCurCanon = false;
    if (haveCur && curCanon.Length > 0 && invHint.Length > 0) {
        
        invHint = _MaybeStripLeaf(invHint, curCanon);

        string curRel;
        if (automata::Helpers::Blocks::TryGetRelDirForName(curCanon, curRel)) {
            preferCurCanon = (_NormalizeRel(curRel) == invHint);
        }
    }

    string srcNameRaw = "UnnamedBlock";
    if (preferCurCanon) {
        srcNameRaw = curCanon;
        
        run.ctx.Set("blockName", curCanon);
    } else if (ctxBlockName.Length > 0) {
        srcNameRaw = ctxBlockName;
    } else if (haveCur && curCanon.Length > 0) {
        srcNameRaw = curCanon;
    }

    string srcNameClean = Text::StripFormatCodes(srcNameRaw).Trim();
    
    string endString = Helpers::Args::ReadStr(args, "endString", "");
    if (endString.Length == 0) { string tmp; if (run.ctx.GetString("endString", tmp)) endString = tmp; }
    endString = _SanitizeSuffixForFile(endString);
    
    string prefix = "AutoMania/block_dump/Nadeo";
    if (args !is null) {
        if (args.HasKey("locationPrefix")) prefix = string(args["locationPrefix"]);
        else if (args.HasKey("location"))  prefix = string(args["location"]);
    }
    prefix = _NormalizeRel(prefix);

    bool flattenLeafDir    = Helpers::Args::ReadBool(args, "flattenLeafDir", true);
    bool includeCustomRoot = Helpers::Args::ReadBool(args, "includeCustomRoot", false);
    
    string onExists = Helpers::Args::ReadLowerStr(args, "onExists", "");
    if (onExists != "skip" && onExists != "overwrite" && onExists != "suffix") {
        bool skipIfExists   = Helpers::Args::ReadBool(args, "skipIfExists", false);
        bool overwriteBool  = Helpers::Args::ReadBool(args, "overwrite", false);
        bool avoidOverwrite = Helpers::Args::ReadBool(args, "avoidOverwrite", true); 
        if (skipIfExists) onExists = "skip";
        else if (overwriteBool) onExists = "overwrite";
        else onExists = avoidOverwrite ? "suffix" : "overwrite";
    }
    
    string invNoLeaf, leafName, invSource, canonicalUsed;
    _SelectInventoryNoLeafAndLeaf(run, args, srcNameClean, invNoLeaf, leafName, invSource, canonicalUsed);

    string baseNoExt = leafName;
    if (baseNoExt.ToLower().EndsWith(".gbx") && baseNoExt.Length > 4) {
        baseNoExt = baseNoExt.SubStr(0, baseNoExt.Length - 4);
    }
    if (endString.Length > 0) baseNoExt += endString;
    
    if (invNoLeaf.Length == 0 && canonicalUsed.Length > 0) {
        string folderTail, baseLeaf;
        if (SavePaths::ComputeTailFromCanonical(canonicalUsed, true, includeCustomRoot, folderTail, baseLeaf)) {
            invNoLeaf = _NormalizeRel(folderTail);
        }
        if (invNoLeaf.Length == 0) {
            invNoLeaf = _NormalizeRel(TailFromCanonical(canonicalUsed));
        }
    }

    if (flattenLeafDir && invNoLeaf.Length > 0) {
        array<string> parts = invNoLeaf.Split("/");
        if (parts.Length > 0) {
            string last = parts[parts.Length - 1];
            string baseNoExtSimple = baseNoExt;
            if (baseNoExtSimple.EndsWith(".Block")) baseNoExtSimple = baseNoExtSimple.SubStr(0, baseNoExtSimple.Length - 6);
            else if (baseNoExtSimple.EndsWith(".Item")) baseNoExtSimple = baseNoExtSimple.SubStr(0, baseNoExtSimple.Length - 5);
            string lastL = last.ToLower();
            if (lastL == baseNoExt.ToLower() || lastL == baseNoExtSimple.ToLower()) {
                array<string> tmp;
                for (uint i = 0; i + 1 < parts.Length; ++i) tmp.InsertLast(parts[i]);
                invNoLeaf = JoinWithSlash(tmp);
            }
        }
    }

    string invNoLeafDeDup = _DropDuplicatedBrandFromTail(prefix, invNoLeaf);
    string relFolder = _JoinRel(prefix, invNoLeafDeDup);
    _EnsureFolderUnderBlocks(relFolder);

    string absFolder = IO::FromUserGameFolder("Blocks/" + relFolder);
    string absBlock  = absFolder + "/" + baseNoExt + ".Block.Gbx";
    string absItem   = absFolder + "/" + baseNoExt + ".Item.Gbx";
    bool existsNow   = IO::FileExists(absBlock) || IO::FileExists(absItem);

    run.ctx.Set("saveExistsAtStart", existsNow ? "1" : "0");
    run.ctx.Set("saveOnExistsMode", onExists);
    run.ctx.Set("saveTargetFolderRel", relFolder);
    run.ctx.Set("saveTargetBaseNoExt", baseNoExt);

    string relBaseNoExt = relFolder + "/" + baseNoExt;

    if (existsNow) {
        if (onExists == "skip") {
            log("save_file: skipping existing: " + relBaseNoExt + " (both .Block/.Item checked).", LogLevel::Info, 407, "Cmd_SaveFile");
            run.ctx.Set("skippedExisting", "1");
            run.ctx.Set("closeActionOnce", "no");
            run.ctx.Set("lastSavedRelNoExt", relBaseNoExt);
            run.ctx.Set("lastSavedRelBlock", relBaseNoExt + ".Block.Gbx");
            run.ctx.Set("lastSavedRelItem",  relBaseNoExt + ".Item.Gbx");
            run.ctx.Set("lastSavedAbsBlock", absBlock);
            run.ctx.Set("lastSavedAbsItem",  absItem);
            run.ctx.Set("lastSavedFolderRel", relFolder);
            run.ctx.Set("lastSavedBaseNoExt", baseNoExt);
            run.ctx.Set("lastSavedCanonicalUsed", canonicalUsed);
            run.ctx.Set("lastSavedInventorySource", invSource);

            return true; 
        } else if (onExists == "overwrite") {
            if (IO::FileExists(absBlock)) IO::Delete(absBlock);
            if (IO::FileExists(absItem))  IO::Delete(absItem);
        } else {
            relBaseNoExt = _NextNonClobberingRelBaseUnderBlocks_NoExt(relFolder, baseNoExt);
        }
    }
    
    log("save_file: src='" + srcNameClean
        + "' | invSource=" + invSource
        + " | prefix='" + prefix
        + "' | invNoLeaf='" + invNoLeaf
        + "' | dedup='" + invNoLeafDeDup
        + "' | relFolder='" + relFolder
        + "' | baseNoExt='" + baseNoExt
        + "' | relBaseNoExt='" + relBaseNoExt
        + "' | onExists=" + onExists, LogLevel::Info, 429, "Cmd_SaveFile");


    editorItem.FileSaveAs();
    yield(3);
    app.BasicDialogs.String = relBaseNoExt;  
    yield();
    app.BasicDialogs.DialogSaveAs_OnValidate();
    yield();
    app.BasicDialogs.DialogSaveAs_OnValidate();
    yield();

    string relBlock = relBaseNoExt + ".Block.Gbx";
    string relItem  = relBaseNoExt + ".Item.Gbx";
    run.ctx.Set("lastSavedRelNoExt", relBaseNoExt);
    run.ctx.Set("lastSavedRelBlock", relBlock);
    run.ctx.Set("lastSavedRelItem",  relItem);
    run.ctx.Set("lastSavedAbsBlock", IO::FromUserGameFolder("Blocks/" + relBlock));
    run.ctx.Set("lastSavedAbsItem",  IO::FromUserGameFolder("Blocks/" + relItem));
    run.ctx.Set("lastSavedFolderRel", relFolder);
    run.ctx.Set("lastSavedBaseNoExt", baseNoExt);
    run.ctx.Set("lastSavedCanonicalUsed", canonicalUsed);
    run.ctx.Set("lastSavedInventorySource", invSource);
    run.ctx.Set("skippedExisting", "0");

    return true;
}

}}}
