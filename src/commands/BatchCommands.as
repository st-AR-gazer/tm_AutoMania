namespace automata {

bool _ReadBoolArg(Json::Value@ args, const string &in key, bool defVal) {
    if (args is null || !args.HasKey(key)) return defVal;
    auto v = args[key];
    auto t = v.GetType();

    if (t == Json::Type::Boolean) return bool(v);

    if (t == Json::Type::String) {
        string s = string(v).ToLower().Trim();
        if (s == "true" || s == "1" || s == "yes" || s == "y") return true;
        if (s == "false" || s == "0" || s == "no"  || s == "n") return false;
        return defVal;
    }

    try { int n = int(v); return n != 0; } catch {}
    try { float f = float(v); return f != 0.0f; } catch {}

    return defVal;
}

string _ReadStrArg(Json::Value@ args, const string &in key, const string &in defVal) {
    if (args is null || !args.HasKey(key)) return defVal;
    auto v = args[key];
    if (v.GetType() == Json::Type::String) return string(v);
    try { return string(v); } catch {}
    return defVal;
}

Json::Value@ _NormalizeContainsArg(Json::Value@ rawContains) {
    if (rawContains is null) return null;
    auto t = rawContains.GetType();
    if (t == Json::Type::String) {
        string s = string(rawContains).Trim();
        if (s.Length == 0) return null;
        Json::Value@ j = Json::Array(); j.Add(s); return j;
    }
    if (t == Json::Type::Array) {
        Json::Value@ outArr = Json::Array();
        for (uint i = 0; i < rawContains.Length; ++i) {
            if (rawContains[i].GetType() != Json::Type::String) continue;
            string s = string(rawContains[i]).Trim();
            if (s.Length > 0) outArr.Add(s);
        }
        if (outArr.Length == 0) return null;
        return outArr;
    }
    return null;
}

void _KickIndexBuildIfNeeded() {
    string err;
    bool ok = Helpers::Blocks::EnsureIndexBuilt(err);
    if (!ok && err.Length > 0) log("EnsureIndexBuilt: " + err, LogLevel::Warn, 55, "_KickIndexBuildIfNeeded");
}

bool _WaitIndexReady(int timeoutMs = 2000) {
    uint until = Time::Now + uint(timeoutMs);
    while (Time::Now < until) {
        if (Helpers::Blocks::gNamesLower.Length > 0) return true;
        yield(10);
    }
    return Helpers::Blocks::gNamesLower.Length > 0;
}

void _TimeSliceYield(uint &out lastYieldMs, uint sliceMs = 600) {
    uint now = Time::Now;
    if (now - lastYieldMs >= sliceMs) {
        yield();
        lastYieldMs = Time::Now;
    }
}

array<string> _ContainsTokensLower(Json::Value@ containsArg) {
    array<string> toks;
    toks.Resize(0);
    if (containsArg is null) return toks;

    for (uint i = 0; i < containsArg.Length; ++i) {
        string s = "";
        try { s = string(containsArg[i]); } catch { continue; }
        s = s.ToLower().Trim();
        if (s.Length > 0) toks.InsertLast(s);
    }
    return toks;
}

bool _PassContains(const string &in nameLower, const array<string> &in toks, bool containsAny) {
    if (toks.Length == 0) return true;

    if (containsAny) {
        for (uint i = 0; i < toks.Length; ++i) {
            if (nameLower.IndexOf(toks[i]) >= 0) return true;
        }
        return false;
    } else {
        for (uint i = 0; i < toks.Length; ++i) {
            if (nameLower.IndexOf(toks[i]) < 0) return false;
        }
        return true;
    }
}

array<int>@ _MatchIndicesByName_Yielding(
    const string &in prefix,
    const string &in suffix,
    Json::Value@ containsArg,
    bool containsAny,
    bool customOnly,
    bool nadeoOnly,
    const array<string> &in excludeContainsLower
) {
    bool onlyCustom = customOnly && !nadeoOnly;
    bool onlyNadeo  = nadeoOnly  && !customOnly;

    string pre = prefix.ToLower().Trim();
    string suf = suffix.ToLower().Trim();
    array<string> toks = _ContainsTokensLower(containsArg);

    bool useExclude = excludeContainsLower.Length > 0;

    array<int>@ outIx = array<int>();

    uint lastYield = Time::Now;
    uint n = Helpers::Blocks::gNamesLower.Length;

    for (uint i = 0; i < n; ++i) {
        _TimeSliceYield(lastYield, 600);

        string nmL = Helpers::Blocks::gNamesLower[i];

        if (useExclude) {
            bool hit = false;
            for (uint k = 0; k < excludeContainsLower.Length; ++k) {
                if (excludeContainsLower[k].Length == 0) continue;
                if (nmL.IndexOf(excludeContainsLower[k]) >= 0) { hit = true; break; }
            }
            if (hit) continue;
        }

        bool isCustom = false;
        if (i < Helpers::Blocks::gIsCustom.Length) isCustom = Helpers::Blocks::gIsCustom[i];

        if (onlyCustom && !isCustom) continue;
        if (onlyNadeo  &&  isCustom) continue;

        if (pre.Length > 0 && !nmL.StartsWith(pre)) continue;
        if (suf.Length > 0 && !nmL.EndsWith(suf))   continue;

        if (!_PassContains(nmL, toks, containsAny)) continue;

        outIx.InsertLast(int(i));
    }

    return outIx;
}

string _BC_Normalize(const string &in s) { return automata::Helpers::SaveFile::_NormalizeRel(s); }
void _BC_ComputeSaveTargetForCanonical(
    const string &in canonicalName,
    const string &in savePrefix,
    bool includeCustomRoot,
    bool flattenLeafDir,
    const string &in endStringSanitized,
    string &out relFolder,
    string &out baseNoExt)
{
    string leaf = automata::Helpers::SaveFile::_LeafFromCanonical(canonicalName);
    baseNoExt = leaf;
    if (baseNoExt.ToLower().EndsWith(".gbx") && baseNoExt.Length > 4) baseNoExt = baseNoExt.SubStr(0, baseNoExt.Length - 4);
    if (endStringSanitized.Length > 0) baseNoExt += endStringSanitized;
    
    string invNoLeaf = "";
    string rel;
    if (Helpers::Blocks::TryGetRelDirForName(canonicalName, rel)) {
        invNoLeaf = _BC_Normalize(rel);
    } else {
        string tail = automata::Helpers::SaveFile::TailFromCanonical(canonicalName);
        invNoLeaf = _BC_Normalize(tail);
    }

    if (flattenLeafDir && invNoLeaf.Length > 0) {
        array<string> parts = invNoLeaf.Split("/");
        if (parts.Length > 0) {
            string last = parts[parts.Length - 1];
            string baseSimple = baseNoExt;
            if (baseSimple.EndsWith(".Block")) baseSimple = baseSimple.SubStr(0, baseSimple.Length - 6);
            else if (baseSimple.EndsWith(".Item")) baseSimple = baseSimple.SubStr(0, baseSimple.Length - 5);
            string lastL = last.ToLower();
            if (lastL == baseNoExt.ToLower() || lastL == baseSimple.ToLower()) {
                array<string> tmp; for (uint i = 0; i + 1 < parts.Length; ++i) tmp.InsertLast(parts[i]);
                invNoLeaf = automata::Helpers::SaveFile::JoinWithSlash(tmp);
            }
        }
    }
    
    string dedup = automata::Helpers::SaveFile::_DropDuplicatedBrandFromTail(savePrefix, invNoLeaf);
    relFolder = automata::Helpers::SaveFile::_JoinRel(savePrefix, dedup);
}

bool _BC_TargetExists(const string &in relFolder, const string &in baseNoExt) {
    string absFolder = IO::FromUserGameFolder("Blocks/" + relFolder);
    string absBlock  = absFolder + "/" + baseNoExt + ".Block.Gbx";
    string absItem   = absFolder + "/" + baseNoExt + ".Item.Gbx";
    return IO::FileExists(absBlock) || IO::FileExists(absItem);
}

int _BC_IndexExistingOutputs_NoExt(const string &in savePrefixNorm, dictionary &out outSet) {
    outSet.DeleteAll();

    string absRoot = IO::FromUserGameFolder("Blocks/" + savePrefixNorm);
    absRoot = absRoot.Replace("\\", "/");
    if (!absRoot.EndsWith("/")) absRoot += "/";

    if (!IO::FolderExists(absRoot)) return 0;

    array<string>@ files = IO::IndexFolder(absRoot, true); 
    if (files is null) return 0;

    int added = 0;
    uint lastYield = Time::Now;

    for (uint i = 0; i < files.Length; ++i) {
        _TimeSliceYield(lastYield, 600);

        string p = files[i];
        p = p.Replace("\\", "/");

        if (p.StartsWith(absRoot)) p = p.SubStr(absRoot.Length);
        if (p.StartsWith("/")) p = p.SubStr(1);
        
        if (p.EndsWith(".Block.Gbx")) {
            p = p.SubStr(0, p.Length - 10); 
        } else if (p.EndsWith(".Item.Gbx")) {
            p = p.SubStr(0, p.Length - 9);  
        } else {
            continue;
        }

        p = _BC_Normalize(p).ToLower();

        if (!outSet.Exists(p)) {
            outSet[p] = 1;
            added++;
        }
    }

    return added;
}

string _BC_MakeExistsKey(const string &in relFolderNorm, const string &in savePrefixNorm, const string &in baseNoExt) {
    string sub = relFolderNorm;
    if (sub.StartsWith(savePrefixNorm)) {
        sub = sub.SubStr(savePrefixNorm.Length);
        if (sub.StartsWith("/")) sub = sub.SubStr(1);
    }

    string key = (sub.Length == 0) ? baseNoExt : (sub + "/" + baseNoExt);
    return _BC_Normalize(key).ToLower();
}

bool Cmd_BatchBuildByNameMatch(FlowRun@ run, Json::Value@ args) {    
    bool customOnly = _ReadBoolArg(args, "customOnly", true);
    bool nadeoOnly  = _ReadBoolArg(args, "nadeoOnly",  false);
    string prefix = _ReadStrArg(args, "prefix", "");
    string suffix = _ReadStrArg(args, "suffix", "");

    Json::Value@ containsArg = null;
    if (args !is null && args.HasKey("contains")) @containsArg = _NormalizeContainsArg(args["contains"]);
    bool containsAny = _ReadBoolArg(args, "containsAny", false);

    bool   skipIfExists      = _ReadBoolArg(args, "skipIfExists", false);
    string savePrefix        = _ReadStrArg(args, "saveLocationPrefix",
                                 _ReadStrArg(args, "locationPrefix", "AutoMania/block_dump/Nadeo"));
    savePrefix = automata::Helpers::SaveFile::_NormalizeRel(savePrefix);
    bool   includeCustomRoot = _ReadBoolArg(args, "includeCustomRoot", false);
    bool   flattenLeafDir    = _ReadBoolArg(args, "saveFlattenLeaf",  true);
    string endStringRaw      = _ReadStrArg(args, "endString", "");
    string endStringSan      = automata::Helpers::SaveFile::_SanitizeSuffixForFile(endStringRaw);
    
    if (Helpers::Blocks::gNamesLower.Length == 0) {
        _KickIndexBuildIfNeeded();
        _WaitIndexReady(2500);
    }
    
    array<string> excludeToks;
    
    {
        excludeToks.Resize(0);

        if (args !is null && args.HasKey("excludeContains")) {
            Json::Value@ ex = args["excludeContains"];
            auto t = ex.GetType();

            if (t == Json::Type::String) {
                string s = string(ex).ToLower().Trim();
                if (s.Length > 0) excludeToks.InsertLast(s);
            } else if (t == Json::Type::Array) {
                for (uint i = 0; i < ex.Length; ++i) {
                    if (ex[i].GetType() != Json::Type::String) continue;
                    string s = string(ex[i]).ToLower().Trim();
                    if (s.Length > 0) excludeToks.InsertLast(s);
                }
            }
        }

        
        if (excludeToks.Length == 0) excludeToks.InsertLast("water");
    }

    array<int>@ listIx = _MatchIndicesByName_Yielding(prefix, suffix, containsArg, containsAny, customOnly, nadeoOnly, excludeToks);
    
    if (skipIfExists && listIx !is null && listIx.Length > 0) {
        uint t0 = Time::Now;

        string savePrefixNorm = _BC_Normalize(savePrefix);

        dictionary existingNoExt;
        int existingCount = _BC_IndexExistingOutputs_NoExt(savePrefixNorm, existingNoExt);

        uint tIndex = Time::Now;

        array<int>@ kept = array<int>();
        int skipped = 0;

        uint lastYield = Time::Now;

        for (uint j = 0; j < listIx.Length; ++j) {
            _TimeSliceYield(lastYield, 600);

            uint i = uint(listIx[j]);
            string nameCanon;
            if (!Helpers::Blocks::TryGetNameByIndex(i, nameCanon)) {
                kept.InsertLast(int(i)); 
                continue;
            }

            string relFolder, baseNoExt;
            _BC_ComputeSaveTargetForCanonical(nameCanon, savePrefixNorm, includeCustomRoot, flattenLeafDir, endStringSan,
                                            relFolder, baseNoExt);

            string relFolderNorm = _BC_Normalize(relFolder);

            
            string key = _BC_MakeExistsKey(relFolderNorm, savePrefixNorm, baseNoExt);

            if (existingNoExt.Exists(key)) {
                skipped++;
            } else {
                kept.InsertLast(int(i));
            }
        }

        @listIx = @kept;

        uint tEnd = Time::Now;

        log("Batch prefilter: skipIfExists=true — indexed " + tostring(existingCount) + " existing outputs in "
            + tostring(int(tIndex - t0)) + "ms; filtered " + tostring(skipped) + " of "
            + tostring(skipped + kept.Length) + " in " + tostring(int(tEnd - tIndex)) + "ms; total "
            + tostring(int(tEnd - t0)) + "ms.", LogLevel::Info, 359, "Cmd_BatchBuildByNameMatch");




    }

    @run.ctx.batchList = null;
    run.ctx.kv["batchListIx"] = @listIx;   
    run.ctx.batchIndex = -1;
    run.ctx.loopActive = false;
    run.ctx.loopStartStep = -1;
    run.ctx.loopEndStep = -1;

    int cnt = listIx is null ? 0 : int(listIx.Length);
    run.ctx.SetInt("batchCount", cnt);

    string msg = "Batch built: " + tostring(cnt) + " match" + (cnt == 1 ? "" : "es")
               + " (customOnly=" + (customOnly ? "true" : "false")
               +  ", nadeoOnly=" + (nadeoOnly  ? "true" : "false") + ")";
    if (prefix.Length > 0) msg += " prefix='" + prefix + "'";
    if (suffix.Length > 0) msg += " suffix='" + suffix + "'";
    if (containsArg !is null) msg += " contains=" + Json::Write(containsArg, false) + (containsAny ? " (any)" : " (all)");
    if (skipIfExists) msg += " [prefilter skipIfExists]";
    log(msg, LogLevel::Info, 383, "Cmd_BatchBuildByNameMatch");

    return true;
}

int _BatchTotal(RunCtx &in ctx) {
    array<int>@ ix = null;
    if (ctx.kv.Exists("batchListIx")) @ix = cast<array<int>@>(ctx.kv["batchListIx"]);
    if (ix !is null) return int(ix.Length);
    if (ctx.batchList is null) return 0;
    return int(ctx.batchList.Length);
}

bool _BatchNameAt(RunCtx &in ctx, int pos, string &out name) {
    array<int>@ ix = null;
    if (ctx.kv.Exists("batchListIx")) @ix = cast<array<int>@>(ctx.kv["batchListIx"]);
    if (ix !is null) {
        if (pos < 0 || pos >= int(ix.Length)) return false;
        uint i = uint(ix[pos]);
        return Helpers::Blocks::TryGetNameByIndex(i, name);
    }
    if (ctx.batchList is null) return false;
    if (pos < 0 || pos >= int(ctx.batchList.Length)) return false;
    name = string(ctx.batchList[pos]);
    return true;
}

bool _SetCurrentByNameWithRetry(const string &in name, string &out err, int maxAttempts = 30, int waitMs = 50) {
    for (int i = 0; i < maxAttempts; ++i) {
        if (Helpers::Blocks::SetCurrentByName(name, err)) return true;
        yield(waitMs);
    }
    return Helpers::Blocks::SetCurrentByName(name, err);
}

string _ComputeInventoryRelDirForName(const string &in canonicalName, bool ) {
    string rel;
    if (Helpers::Blocks::TryGetRelDirForName(canonicalName, rel)) return rel;
    return "";
}

bool Cmd_BatchLoopBegin(FlowRun@ run, Json::Value@ args) {
    int start = int(run.ctx.stepIndex);
    int depth = 0;
    int endIdx = -1;
    for (uint j = uint(start + 1); j < run.flow.steps.Length; ++j) {
        auto sj = run.flow.steps[j];
        if (sj is null) continue;
        string c = sj.cmd;
        if (c == "batch_loop_begin") depth++;
        else if (c == "batch_loop_end") {
            if (depth == 0) { endIdx = int(j); break; }
            depth--;
        }
    }
    if (endIdx < 0) {
        run.ctx.lastError = "batch_loop_begin: matching batch_loop_end not found.";
        return false;
    }
    
    @run.ctx.batchList = (run.ctx.batchList is null) ? Json::Array() : run.ctx.batchList;
    int total = _BatchTotal(run.ctx);

    run.ctx.loopStartStep = start + 1;
    run.ctx.loopEndStep   = endIdx;

    if (total <= 0) {
        log("BatchLoop: no items — skipping loop body.", LogLevel::Info, 450, "Cmd_BatchLoopBegin");
        run.ctx.jumpToStep = endIdx + 1;
        run.ctx.loopActive = false;
        return true;
    }

    run.ctx.batchIndex = 0;
    run.ctx.loopActive = true;

    string nameNow;
    if (!_BatchNameAt(run.ctx, 0, nameNow)) {
        log("BatchLoop: failed to resolve name at #0", LogLevel::Warn, 461, "Cmd_BatchLoopBegin");
        nameNow = "";
    }
    run.ctx.Set("blockName", nameNow);

    string invRel = _ComputeInventoryRelDirForName(nameNow, true);
    run.ctx.Set("inventoryRelDir", invRel);

    string err;
    if (!_SetCurrentByNameWithRetry(nameNow, err)) {
        log("BatchLoop: failed to set current block '" + nameNow + "'. " + (err.Length > 0 ? err : ""), LogLevel::Warn, 471, "Cmd_BatchLoopBegin");
    }

    return true;
}

bool Cmd_BatchLoopEnd(FlowRun@ run, Json::Value@ args) {
    if (!run.ctx.loopActive) return true;
    int total = _BatchTotal(run.ctx);
    int next  = run.ctx.batchIndex + 1;

    if (next < total) {
        run.ctx.batchIndex = next;
        string nameNow;
        if (!_BatchNameAt(run.ctx, next, nameNow)) {
            log("BatchLoop: failed to resolve name at #" + tostring(next), LogLevel::Warn, 486, "Cmd_BatchLoopEnd");
            nameNow = "";
        }
        run.ctx.Set("blockName", nameNow);

        string invRel = _ComputeInventoryRelDirForName(nameNow, true);
        run.ctx.Set("inventoryRelDir", invRel);

        string err;
        if (!_SetCurrentByNameWithRetry(nameNow, err)) {
            log("BatchLoop: failed to set current block '" + nameNow + "'. " + (err.Length > 0 ? err : ""), LogLevel::Warn, 496, "Cmd_BatchLoopEnd");
        }

        if (run.ctx.loopStartStep >= 0) run.ctx.jumpToStep = run.ctx.loopStartStep;
    } else {
        run.ctx.loopActive = false;
    }
    return true;
}

void RegisterBatchCommands(CommandRegistry@ R) {
    R.Register("batch_build_by_name_match",  CommandFn(Cmd_BatchBuildByNameMatch));
    R.Register("batch_loop_begin",           CommandFn(Cmd_BatchLoopBegin));
    R.Register("batch_loop_end",             CommandFn(Cmd_BatchLoopEnd));
}

}
