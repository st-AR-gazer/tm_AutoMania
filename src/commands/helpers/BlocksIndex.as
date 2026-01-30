namespace automata { namespace Helpers { namespace Blocks {

array<string>              gNamesLower;
array<string>              gCanon;
array<bool>                gIsCustom;
array<CGameCtnArticle@>    gArticles;
array<string>              gRelDir;
array<CGameCtnBlockInfo@>  gInfos;
dictionary                 gIxByNameLower;
array<int>                 gIxNadeo;
array<int>                 gIxCustom;

bool   gIndexBuilt = false;

bool gAutoAliasUniqueSuggestionForNadeo  = true;
bool gAutoAliasUniqueSuggestionForCustom = false;

CGameCtnBlockInfo@ gCurrent = null;
string gCurrentName = "";
dictionary gAliasByNameLower;

const uint kYieldBudgetMs = 90;
uint gLastYieldMs = 0;

uint gAutoAliasMinNameLen  = 12;
uint gAutoAliasMaxLenDiff  = 12;

void _BudgetYield() {
    uint now = Time::Now;
    if (gLastYieldMs == 0) gLastYieldMs = now;
    if (now - gLastYieldMs >= kYieldBudgetMs) {
        gLastYieldMs = now;
        yield();
    }
}

void _ClearIndex() {
    gNamesLower.RemoveRange(0, gNamesLower.Length);
    gCanon.RemoveRange(0, gCanon.Length);
    gIsCustom.RemoveRange(0, gIsCustom.Length);
    gArticles.RemoveRange(0, gArticles.Length);
    gRelDir.RemoveRange(0, gRelDir.Length);
    gInfos.RemoveRange(0, gInfos.Length);
    gIxByNameLower.DeleteAll();
    gIxNadeo.RemoveRange(0, gIxNadeo.Length);
    gIxCustom.RemoveRange(0, gIxCustom.Length);

    gAliasByNameLower.DeleteAll();

    gIndexBuilt = false;
    @gCurrent = null;
    gCurrentName = "";

    gLastYieldMs = 0;
}

void _ReserveForTypicalIndexSize(uint n = 28000) {
    gNamesLower.Reserve(n);
    gCanon.Reserve(n);
    gIsCustom.Reserve(n);
    gArticles.Reserve(n);
    gRelDir.Reserve(n);
    gInfos.Reserve(n);

    gIxNadeo.Reserve(n);
    gIxCustom.Reserve(n);
}

string _SanitizeSeg(const string &in s) {
    _BudgetYield();

    string outS = "";
    for (int i = 0; i < s.Length; ++i) {
        string ch = s.SubStr(i, 1);
        if ((ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z")
         || (ch >= "0" && ch <= "9") || ch == "_" || ch == "-") outS += ch;
        else if (ch == " ") outS += "_";
        else outS += "-";
    }
    return outS;
}

string _ParentDir(const string &in p) {
    int k = p.LastIndexOf("/");
    return k <= 0 ? "" : p.SubStr(0, k);
}

bool _IsMixedDir(CGameCtnArticleNodeDirectory@ dir) {
    if (dir is null) return false;

    bool hasN = false, hasC = false;

    for (uint i = 0; i < dir.ChildNodes.Length; ++i) {
        if ((i & 31) == 0) _BudgetYield();

        CGameCtnArticleNode@ ch = dir.ChildNodes[i];
        if (ch is null || ch.IsDirectory) continue;

        CGameCtnArticleNodeArticle@ ana = cast<CGameCtnArticleNodeArticle@>(ch);
        if (ana is null || ana.Article is null) continue;

        string idLower = ana.Article.IdName.ToLower();
        bool isCustom = idLower.EndsWith("customblock");
        if (isCustom) hasC = true; else hasN = true;

        if (hasC && hasN) return true;
    }
    return false;
}

void _AddArticle(CGameCtnArticleNodeArticle@ ana, const string &in effRelDir) {
    _BudgetYield();

    if (ana is null || ana.Article is null) return;

    string canon = ana.Article.IdName;
    string low   = canon.ToLower();
    bool isC     = low.EndsWith("customblock");

    int ix = int(gCanon.Length);

    gNamesLower.InsertLast(low);
    gCanon.InsertLast(canon);
    gIsCustom.InsertLast(isC);
    gArticles.InsertLast(ana.Article);

    CGameCtnBlockInfo@ nil = null;
    gInfos.InsertLast(nil);

    gRelDir.InsertLast(effRelDir);

    gIxByNameLower[low] = ix;

    if (isC) gIxCustom.InsertLast(ix);
    else     gIxNadeo.InsertLast(ix);
}

void _Explore(CGameCtnArticleNodeDirectory@ dir, const string &in parentRel) {
    _BudgetYield();
    if (dir is null) return;

    string seg = _SanitizeSeg(dir.Name);
    string thisRel = parentRel;
    if (seg.Length > 0) thisRel = (thisRel.Length == 0) ? seg : (thisRel + "/" + seg);

    bool mixed = _IsMixedDir(dir);
    string effForArticles = mixed ? _ParentDir(thisRel) : thisRel;

    for (uint i = 0; i < dir.ChildNodes.Length; ++i) {
        if ((i & 31) == 0) _BudgetYield();

        CGameCtnArticleNode@ ch = dir.ChildNodes[i];
        if (ch is null || ch.IsDirectory) continue;
        _AddArticle(cast<CGameCtnArticleNodeArticle@>(ch), effForArticles);
    }

    for (uint i = 0; i < dir.ChildNodes.Length; ++i) {
        if ((i & 31) == 0) _BudgetYield();

        CGameCtnArticleNode@ ch = dir.ChildNodes[i];
        if (ch is null || !ch.IsDirectory) continue;
        _Explore(cast<CGameCtnArticleNodeDirectory@>(ch), thisRel);
    }
}

bool _MaterializeInfo(uint i, CGameCtnBlockInfo@ &out info) {
    if (i >= gInfos.Length) return false;
    if (gInfos[i] is null) {
        @gInfos[i] = cast<CGameCtnBlockInfo>(gArticles[i].LoadedNod);
    }
    @info = gInfos[i];
    return info !is null;
}

bool RebuildIndex(string &out err) {
    _ClearIndex();
    _ReserveForTypicalIndexSize(28000);

    gLastYieldMs = Time::Now;
    yield();

    CGameCtnApp@ app = GetApp();
    if (app is null) { err = "App is null."; return false; }

    CGameCtnEditorCommon@ editor = cast<CGameCtnEditorCommon@>(app.Editor);
    if (editor is null) { err = "Not in Map Editor. Open a map first."; return false; }

    CGameEditorPluginMapMapType@ pmt = editor.PluginMapType;
    if (pmt is null) { err = "PluginMapType is null."; return false; }

    CGameEditorGenericInventory@ inv = pmt.Inventory;
    if (inv is null) { err = "Inventory is null."; return false; }
    if (inv.RootNodes.Length == 0) { err = "Inventory.RootNodes is empty."; return false; }

    for (uint r = 0; r < inv.RootNodes.Length; ++r) {
        _BudgetYield();

        CGameCtnArticleNodeDirectory@ rootDir = cast<CGameCtnArticleNodeDirectory@>(inv.RootNodes[r]);
        if (rootDir is null) continue;

        _Explore(rootDir, "");
        _BudgetYield();
    }

    gIndexBuilt = true;
    log("Blocks index built: " + gCanon.Length + " entries.", LogLevel::Info, 206, "RebuildIndex");
    err = "";
    return true;
}

bool EnsureIndexBuilt(string &out err) {
    if (gIndexBuilt) { err = ""; return true; }
    return RebuildIndex(err);
}

int _FindExactIndex(const string &in nameLower) {
    if (gIxByNameLower.Exists(nameLower)) {
        try { return int(gIxByNameLower[nameLower]); } catch { return -1; }
    }
    return -1;
}

void Suggest(const string &in nameLower, array<string> &out suggestions) {
    for (uint i = 0; i < gCanon.Length && suggestions.Length < 8; ++i) {
        if ((i & 511) == 0) _BudgetYield();
        if (gNamesLower[i].Contains(nameLower)) suggestions.InsertLast(gCanon[i]);
    }
}

bool TryFindBlockInfoByName(const string &in name, CGameCtnBlockInfo@ &out info, string &out canonical, string &out err) {
    if (!EnsureIndexBuilt(err)) return false;

    string q = name.ToLower().Trim();
    if (q.Length == 0) { err = "Block name is empty."; return false; }

    int ix = _FindExactIndex(q);
    if (ix >= 0) {
        canonical = gCanon[ix];
        if (!_MaterializeInfo(uint(ix), info)) {
            err = "LoadedNod is null for: " + canonical;
            return false;
        }
        log("Block resolved: " + canonical + " | name='" + name + "'", LogLevel::Debug, 243, "TryFindBlockInfoByName");
        err = "";
        return true;
    }

    if (gAliasByNameLower.Exists(q)) {
        string mapped = "";
        try { mapped = string(gAliasByNameLower[q]); } catch {}
        if (mapped.Length > 0) {
            int ix2 = _FindExactIndex(mapped);
            if (ix2 >= 0) {
                canonical = gCanon[ix2];
                if (!_MaterializeInfo(uint(ix2), info)) {
                    err = "LoadedNod is null for: " + canonical;
                    return false;
                }
                log("Block resolved via alias: " + canonical + " | alias='" + name + "'", LogLevel::Debug, 259, "TryFindBlockInfoByName");
                err = "";
                return true;
            }
        }
    }

    array<string> sugg;
    Suggest(q, sugg);

    bool isCustom = q.EndsWith("customblock");
    bool allowAuto = isCustom ? gAutoAliasUniqueSuggestionForCustom : gAutoAliasUniqueSuggestionForNadeo;

    if (allowAuto && q.Length >= gAutoAliasMinNameLen && sugg.Length == 1) {
        string cand = sugg[0];
        string candL = cand.ToLower();

        bool related = (candL.IndexOf(q) >= 0) || (q.IndexOf(candL) >= 0);
        int diff = int(candL.Length) - int(q.Length); if (diff < 0) diff = -diff;

        if (related && uint(diff) <= gAutoAliasMaxLenDiff) {
            int ix3 = _FindExactIndex(candL);
            if (ix3 >= 0) {
                canonical = gCanon[ix3];
                if (!_MaterializeInfo(uint(ix3), info)) {
                    err = "LoadedNod is null for: " + canonical;
                    return false;
                }

                gAliasByNameLower[q] = candL;

                log("Auto-resolved block name '" + name + "' -> '" + canonical + "' (prefer Article.IdName).", LogLevel::Warn, 290, "TryFindBlockInfoByName");


                err = "";
                return true;
            }
        }
    }

    log("Block not found: " + name, LogLevel::Debug, 299, "TryFindBlockInfoByName");
    err = "Block not found: " + name;
    if (sugg.Length > 0) err += " | Did you mean: " + string::Join(sugg, ", ");
    return false;
}

bool SetCurrentByName(const string &in name, string &out err) {
    CGameCtnBlockInfo@ info;
    string canon;
    if (!TryFindBlockInfoByName(name, info, canon, err)) return false;
    @gCurrent = info;
    gCurrentName = canon;
    return true;
}

bool GetCurrent(CGameCtnBlockInfo@ &out info, string &out name) {
    if (gCurrent is null) return false;
    @info = gCurrent;
    name  = gCurrentName;
    return true;
}

string GetCurrentName() { return gCurrentName; }
uint GetIndexSize() { return gCanon.Length; }

Json::Value@ ListBlocksByNameMatch(const string &in prefix, const string &in suffix, Json::Value@ containsOpt, bool containsAny, bool customOnly) {
    string pfxLower = prefix.ToLower();
    string sfxLower = suffix.ToLower();
    bool checkPfx = pfxLower.Length > 0;
    bool checkSfx = sfxLower.Length > 0;

    array<string> conts;
    if (containsOpt !is null) {
        auto t = containsOpt.GetType();
        if (t == Json::Type::Array) {
            for (uint i = 0; i < containsOpt.Length; ++i) {
                if (containsOpt[i].GetType() == Json::Type::String) {
                    conts.InsertLast(string(containsOpt[i]).ToLower());
                }
            }
        } else if (t == Json::Type::String) {
            conts.InsertLast(string(containsOpt).ToLower());
        }
    }
    bool checkConts = conts.Length > 0;

    Json::Value@ arr = Json::Array();
    for (uint i = 0; i < gCanon.Length; ++i) {
        if ((i & 511) == 0) _BudgetYield();

        if (customOnly && !gIsCustom[i]) continue;

        string nm = gNamesLower[i];
        if (checkPfx && !nm.StartsWith(pfxLower)) continue;
        if (checkSfx && !nm.EndsWith(sfxLower))   continue;

        if (checkConts) {
            if (containsAny) {
                bool any = false;
                for (uint k = 0; k < conts.Length; ++k) {
                    if (nm.IndexOf(conts[k]) >= 0) { any = true; break; }
                }
                if (!any) continue;
            } else {
                bool all = true;
                for (uint k = 0; k < conts.Length; ++k) {
                    if (nm.IndexOf(conts[k]) < 0) { all = false; break; }
                }
                if (!all) continue;
            }
        }

        arr.Add(gCanon[i]);
    }
    return arr;
}

Json::Value@ ListBlocksByNameEndsWith(const string &in suffixCaseSensitive, bool customOnly) {
    return ListBlocksByNameMatch("", suffixCaseSensitive, null, false, customOnly);
}

bool TryGetRelDirForName(const string &in canonicalName, string &out relDir) {
    string key = canonicalName.ToLower();
    int ix = _FindExactIndex(key);
    if (ix < 0) { relDir = ""; return false; }
    relDir = gRelDir[uint(ix)];
    return true;
}

bool TryGetNameByIndex(uint ix, string &out name) {
    if (ix >= gCanon.Length) return false;
    name = gCanon[ix];
    return true;
}

array<int>@ MatchIndicesByName(const string &in prefix, const string &in suffix,
                               Json::Value@ containsOpt, bool containsAny,
                               bool customOnly, bool nadeoOnly)
{
    string err;
    EnsureIndexBuilt(err);

    string pfxLower = prefix.ToLower();
    string sfxLower = suffix.ToLower();
    bool checkPfx = pfxLower.Length > 0;
    bool checkSfx = sfxLower.Length > 0;

    array<string> conts;
    if (containsOpt !is null) {
        auto t = containsOpt.GetType();
        if (t == Json::Type::Array) {
            for (uint i = 0; i < containsOpt.Length; ++i) {
                if (containsOpt[i].GetType() == Json::Type::String) {
                    conts.InsertLast(string(containsOpt[i]).ToLower());
                }
            }
        } else if (t == Json::Type::String) {
            conts.InsertLast(string(containsOpt).ToLower());
        }
    }
    bool checkConts = conts.Length > 0;

    array<int>@ baseIx = null;
    if (customOnly && !nadeoOnly)      @baseIx = @gIxCustom;
    else if (nadeoOnly && !customOnly) @baseIx = @gIxNadeo;

    array<int>@ outIx = array<int>();

    if (baseIx !is null) {
        for (uint j = 0; j < baseIx.Length; ++j) {
            if ((j & 1023) == 0) _BudgetYield();

            uint i = uint(baseIx[j]);
            string nm = gNamesLower[i];
            if (checkPfx && !nm.StartsWith(pfxLower)) continue;
            if (checkSfx && !nm.EndsWith(sfxLower))   continue;

            if (checkConts) {
                if (containsAny) {
                    bool any = false;
                    for (uint k = 0; k < conts.Length; ++k) {
                        if (nm.IndexOf(conts[k]) >= 0) { any = true; break; }
                    }
                    if (!any) continue;
                } else {
                    bool all = true;
                    for (uint k = 0; k < conts.Length; ++k) {
                        if (nm.IndexOf(conts[k]) < 0) { all = false; break; }
                    }
                    if (!all) continue;
                }
            }

            outIx.InsertLast(int(i));
        }
        return outIx;
    }

    for (uint i = 0; i < gCanon.Length; ++i) {
        if ((i & 1023) == 0) _BudgetYield();

        if (customOnly && !gIsCustom[i]) continue;
        if (nadeoOnly  &&  gIsCustom[i]) continue;

        string nm = gNamesLower[i];
        if (checkPfx && !nm.StartsWith(pfxLower)) continue;
        if (checkSfx && !nm.EndsWith(sfxLower))   continue;

        if (checkConts) {
            if (containsAny) {
                bool any = false;
                for (uint k = 0; k < conts.Length; ++k) {
                    if (nm.IndexOf(conts[k]) >= 0) { any = true; break; }
                }
                if (!any) continue;
            } else {
                bool all = true;
                for (uint k = 0; k < conts.Length; ++k) {
                    if (nm.IndexOf(conts[k]) < 0) { all = false; break; }
                }
                if (!all) continue;
            }
        }

        outIx.InsertLast(int(i));
    }

    return outIx;
}

}}}
