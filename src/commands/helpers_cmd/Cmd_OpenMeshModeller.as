namespace automata { namespace Helpers { namespace OpenMeshModeller {

const uint DEFAULT_OVERLAY = 2;
const string PROPS_ROOT_A = "0/4/1/0/1";

const string REL_ROW_EDIT = "6/0"; 
const string REL_ROW_NEW  = "6/3"; 
const string REL_ROW_VAL  = "6/4"; 

const string BTI_ROOT     = "0/4/1/0/1/14/5";
const string BTI_EDIT     = "0/4/1/0/1/14/5/0";
const string BTI_NEW      = "0/4/1/0/1/14/5/3";

const uint   OVL_WARN_CUBE   = 16;
const string PATH_WARN_LABEL = "1/0/2/1";   
const string PATH_WARN_OKBTN = "1/0/2/0/0"; 

const string CTX_MM_PENDING_ACTIVE  = "mm.pending.active";   
const string CTX_MM_PENDING_BLOCK   = "mm.pending.block";
const string CTX_MM_PENDING_VARIANT = "mm.pending.variant";
const string CTX_MM_PENDING_MODE    = "mm.pending.mode";
const string CTX_MM_PENDING_PREFER  = "mm.pending.prefer";

string _ParsePrefer(const Json::Value@ args, const string &in defaultPref) {
    string pref = defaultPref;
    if (args !is null && args.HasKey("prefer")) pref = string(args["prefer"]);
    pref = pref.ToLower();
    if (pref != "edit" && pref != "new" && pref != "auto") pref = "auto";
    return pref;
}

void _ResetPendingCtx(FlowRun@ run) {
    if (run is null) return;
    run.ctx.Set(CTX_MM_PENDING_ACTIVE,  "0");
    run.ctx.Set(CTX_MM_PENDING_BLOCK,   "");
    run.ctx.Set(CTX_MM_PENDING_VARIANT, "");
    run.ctx.Set(CTX_MM_PENDING_MODE,    "");
    run.ctx.Set(CTX_MM_PENDING_PREFER,  "");
}

bool _IsDigit(uint8 c) { return (c >= 48 && c <= 57); }
bool _IsAlpha(uint8 c) { return ( (c >= 65 && c <= 90) || (c >= 97 && c <= 122) ); }

string _ExtractVariantKey(const string &in raw) {
    string s = Text::StripFormatCodes(raw);
    s = UiNav::CleanUiFormatting(s);

    int L = int(s.Length);
    int i = 0;
    
    int letterPos = -1;
    string letter = "";
    for (; i < L; ++i) {
        uint8 c = s[uint(i)];
        if (_IsAlpha(c)) {
            letterPos = i;
            letter = s.SubStr(i, 1).ToLower();
            break;
        }
    }
    if (letterPos < 0) return "";
    
    i = letterPos + 1;
    while (i < L && !_IsDigit(s[uint(i)])) i++;
    if (i >= L) return "";

    int n1 = 0;
    bool any1 = false;
    while (i < L && _IsDigit(s[uint(i)])) {
        any1 = true;
        n1 = (n1 * 10) + int(s[uint(i)] - 48);
        i++;
    }
    if (!any1) return "";
    
    while (i < L && !_IsDigit(s[uint(i)])) i++;
    if (i >= L) return "";

    int n2 = 0;
    bool any2 = false;
    while (i < L && _IsDigit(s[uint(i)])) {
        any2 = true;
        n2 = (n2 * 10) + int(s[uint(i)] - 48);
        i++;
    }
    if (!any2) return "";

    return letter + "-" + tostring(n1) + "-" + tostring(n2);
}

string _NormalizeUiLabel(const string &in raw) {
    return UiNav::NormalizeForCompare(Text::StripFormatCodes(raw)).Trim();
}

void _AppendWarning(FlowRun@ run,
                    const string &in type,
                    const string &in blockCanon,
                    const string &in variantLabel,
                    const string &in message)
{
    if (run is null) return;

    Json::Value@ ev = Json::Object();
    ev["type"]    = type;
    ev["block"]   = blockCanon;
    if (variantLabel.Length > 0) ev["variant"] = variantLabel;
    ev["message"] = message;
    ev["step"]    = int(run.ctx.stepIndex);
    ev["timeNow"] = int(Time::Now);
    if (run.flow !is null) ev["flow"] = run.flow.name;

    string line = Json::Write(ev, false);

    string prev;
    bool had = run.ctx.GetString("warningsJsonl", prev);
    if (had && prev.Length > 0) prev += line + "\n";
    else                        prev  = line + "\n";
    run.ctx.Set("warningsJsonl", prev);

    
    string cS; int c = 0;
    if (run.ctx.GetString("warningsCount", cS) && cS.Length > 0) c = Text::ParseInt(cS);
    c++;
    run.ctx.Set("warningsCount", tostring(c));
}

namespace CrashSkip {

    bool gInit = false;
    dictionary gVariantsSpecByBlockLower; 
    dictionary gReasonByBlockLower;       

    void _Add(const string &in blockCanon, const string &in variantsSpec, const string &in reason) {
        string b = blockCanon.ToLower().Trim();
        string s = variantsSpec.ToLower().Trim();
        gVariantsSpecByBlockLower[b] = s;
        gReasonByBlockLower[b] = reason;
    }

    void _Init() {
        if (gInit) return;
        gInit = true;

        _Add("DecoPlatformSlope2Base2CurveOut",      "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformSlope2Base2CurveIn",       "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformSlope2Start2Curve2In",     "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformSlope2Start2Curve4Out",    "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformSlope2End2Curve2Out",      "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformSlope2End2Curve4In",       "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformSlope4Base4CurveOut",      "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformSlope4Base4CurveIn",       "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformSlope2Start2Base5",        "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");

        _Add("DecoPlatformDirtSlope2Base2CurveOut",  "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformDirtSlope2Base2CurveIn",   "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformDirtSlope2Start2Curve2In", "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformDirtSlope2Start2Curve4Out","A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformDirtSlope2End2Curve2Out",  "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformDirtSlope2End2Curve4In",   "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformDirtSlope4Base4CurveOut",  "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformDirtSlope4Base4CurveIn",   "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformDirtSlope2Start2Base5",    "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");

        _Add("DecoPlatformIceSlope2Base2CurveOut",   "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformIceSlope2Base2CurveIn",    "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformIceSlope2Start2Curve2In",  "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformIceSlope2Start2Curve4Out", "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformIceSlope2End2Curve2Out",   "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformIceSlope2End2Curve4In",    "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformIceSlope4Base4CurveOut",   "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformIceSlope4Base4CurveIn",    "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");
        _Add("DecoPlatformIceSlope2Start2Base5",     "A-1-1|G-1-1|G-2-1|A-2-1","Known to crash the game when opened in Mesh Modeller.");

        log("CrashSkip: initialized " + tostring(gVariantsSpecByBlockLower.GetSize()) + " block rule(s).", LogLevel::Debug, 207, "_Init");

    }

    bool ShouldSkip(const string &in blockCanon,
                    const string &in variantLabelOrKey,
                    string &out reasonOut)
    {
        _Init();

        reasonOut = "";
        if (blockCanon.Length == 0) return false;

        string key = blockCanon.ToLower().Trim();
        if (key.EndsWith("customblock") && key.Length > 9) {
            key = key.SubStr(0, key.Length - 9).Trim();
        }

        if (!gVariantsSpecByBlockLower.Exists(key)) return false;

        string spec = string(gVariantsSpecByBlockLower[key]);
        string rsn = gReasonByBlockLower.Exists(key) ? string(gReasonByBlockLower[key]) : "Known crash risk.";
        reasonOut = rsn;

        if (spec == "*" || spec == "all") {
            log("CrashSkip: block='" + blockCanon + "' spec='*' -> SKIP ALL", LogLevel::Debug, 232, "ShouldSkip");
            return true;
        }

        string vKey = _ExtractVariantKey(variantLabelOrKey);
        if (vKey.Length == 0) {
            string tmp = variantLabelOrKey.ToLower().Trim();
            if (tmp.Length >= 5 && tmp.IndexOf("-") >= 0) vKey = tmp;
        }
        vKey = vKey.ToLower().Trim();

        if (vKey.Length == 0) {
            log("CrashSkip: block='" + blockCanon + "' has rules but could not parse variant key from label='" + variantLabelOrKey + "'", LogLevel::Debug, 244, "ShouldSkip");

            return false;
        }

        string tmpSpec = spec;
        tmpSpec = tmpSpec.Replace(",", "|");
        string[] toks = tmpSpec.Split("|");

        log("CrashSkip: block='" + blockCanon + "' variantKey='" + vKey + "' spec='" + spec + "'", LogLevel::Debug, 253, "ShouldSkip");

        for (uint i = 0; i < toks.Length; ++i) {
            string t = toks[i].Trim().ToLower();
            if (t.Length == 0) continue;
            if (vKey == t || vKey.IndexOf(t) >= 0) {
                log("CrashSkip: MATCH token='" + t + "' -> SKIP", LogLevel::Debug, 260, "ShouldSkip");
                return true;
            }
        }

        return false;
    }

}

uint _Len(CControlBase@ n) {
    if (n is null) return 0;
    CControlFrame@ f = cast<CControlFrame>(n);
    if (f !is null) return f.Childs.Length;
    CControlListCard@ lc = cast<CControlListCard>(n);
    if (lc !is null) return lc.Childs.Length;
    return 0;
}

CControlBase@ _At(CControlBase@ n, uint i) {
    if (n is null) return null;
    CControlFrame@ f = cast<CControlFrame>(n);
    if (f !is null) {
        if (i < f.Childs.Length) return f.Childs[i];
        return null;
    }
    CControlListCard@ lc = cast<CControlListCard>(n);
    if (lc !is null) {
        if (i < lc.Childs.Length) return lc.Childs[i];
        return null;
    }
    return null;
}

CControlBase@ _ResolveRel(CControlBase@ base, const string &in spec) {
    if (base is null) return null;
    if (spec.Length == 0) return base;

    string[] parts = spec.Split("/");
    CControlBase@ cur = base;
    for (uint i = 0; i < parts.Length; ++i) {
        string tok = parts[i].Trim();
        if (tok.Length == 0) continue;
        if (tok == "*") {
            uint L = _Len(cur);
            bool advanced = false;
            for (uint c = 0; c < L; ++c) {
                CControlBase@ ch = _At(cur, c);
                if (ch is null) continue;
                @cur = ch; advanced = true; break;
            }
            if (!advanced) return null;
        } else {
            int idx = Text::ParseInt(tok);
            if (idx < 0) return null;
            CControlBase@ ch2 = _At(cur, uint(idx));
            if (ch2 is null) return null;
            @cur = ch2;
        }
    }
    return cur;
}

CControlListCard@ _FindPropertiesListCard(uint overlay, string &out resolvedPath) {
    resolvedPath = "";

    for (int attempt = 0; attempt < 12; ++attempt) {
        CControlBase@ a = UiNav::ResolvePath(PROPS_ROOT_A, overlay);
        if (a !is null) {
            CControlListCard@ lca = cast<CControlListCard>(a);
            if (lca !is null) { resolvedPath = PROPS_ROOT_A; return lca; }
        }

        CControlFrame@ root = UiNav::RootAtOverlay(overlay);
        if (root !is null) {
            array<CControlBase@> q; q.InsertLast(root);
            array<string>       qp; qp.InsertLast("");
            uint scanned = 0, maxScan = 3000;

            while (q.Length > 0 && scanned < maxScan) {
                CControlBase@ cur = q[0]; q.RemoveAt(0);
                string curPath = qp[0];  qp.RemoveAt(0);
                scanned++;

                CControlListCard@ lc = cast<CControlListCard>(cur);
                if (lc !is null) {
                    bool looksRight = false;
                    for (int ri = 10; ri < 22; ++ri) {
                        CControlBase@ row = _ResolveRel(lc, tostring(ri));
                        if (row is null) break;
                        CControlBase@ bEdit = _ResolveRel(row, REL_ROW_EDIT);
                        CControlBase@ bNew  = _ResolveRel(row, REL_ROW_NEW);
                        if (bEdit !is null || bNew !is null) { looksRight = true; break; }
                    }
                    if (looksRight) { resolvedPath = curPath; return lc; }
                }

                uint L = _Len(cur);
                for (uint i = 0; i < L; ++i) {
                    CControlBase@ ch = _At(cur, i);
                    if (ch is null) continue;
                    string np = curPath.Length == 0 ? tostring(i) : curPath + "/" + tostring(i);
                    q.InsertLast(ch); qp.InsertLast(np);
                }
            }
        }

        yield(5);
    }
    return null;
}

void _CollectVariantRows(CControlListCard@ propsLC, array<int> &out rowIndices, array<string> &out labels) {
    rowIndices.Resize(0); labels.Resize(0);
    if (propsLC is null) return;

    bool started = false;
    for (int ri = 8; ri < 8 + 256; ++ri) {
        CControlBase@ row = _ResolveRel(propsLC, tostring(ri));
        if (row is null) {
            if (started) break;
            continue;
        }

        CControlBase@ bEdit = _ResolveRel(row, REL_ROW_EDIT);
        CControlBase@ bNew  = _ResolveRel(row, REL_ROW_NEW);
        bool isVariant = (bEdit !is null || bNew !is null);

        if (!isVariant) {
            if (started) break;
            continue;
        }

        started = true;

        string lbl = UiNav::ReadText(_ResolveRel(row, REL_ROW_VAL));
        if (lbl.Length == 0) {
            uint L = _Len(row);
            for (uint j = 0; j < L && lbl.Length == 0; ++j) {
                CControlBase@ sub = _At(row, j);
                string t = UiNav::ReadText(sub);
                if (t.Length > 0) lbl = t;
            }
        }

        rowIndices.InsertLast(ri);
        labels.InsertLast(lbl);
    }
}

int _SelectVariantPos(const Json::Value@ args, const array<int> &in uiIdx, const array<string> &in labels) {
    if (uiIdx.Length == 0) return -1;
    if (args is null) return 0;

    if (args.HasKey("variantIndex")) {
        int k = int(args["variantIndex"]);
        if (k >= 0 && k < int(uiIdx.Length)) return k;
    }

    if (args.HasKey("variantKey")) {
        string wantRaw = string(args["variantKey"]);
        string wantKey = _ExtractVariantKey(wantRaw);
        wantKey = wantKey.ToLower().Trim();
        if (wantKey.Length > 0) {
            for (int i = 0; i < int(labels.Length); ++i) {
                string candKey = _ExtractVariantKey(labels[uint(i)]).ToLower().Trim();
                if (candKey == wantKey) return i;
            }
        }

        string key = wantRaw.ToLower();
        if (key.Length > 0) {
            for (int i = 0; i < int(labels.Length); ++i) {
                if (labels[uint(i)].ToLower().IndexOf(key) >= 0) return i;
            }
        }
    }

    return 0;
}

bool _ClickVariant(CControlListCard@ propsLC, int uiRow, const string &in prefer) {
    if (propsLC is null || uiRow < 0) return false;

    CControlBase@ row = _ResolveRel(propsLC, tostring(uiRow));
    if (row is null) return false;

    CControlButton@ bEdit = cast<CControlButton>(_ResolveRel(row, REL_ROW_EDIT));
    CControlButton@ bNew  = cast<CControlButton>(_ResolveRel(row, REL_ROW_NEW));

    bool editHidden = (bEdit is null) ? true : bEdit.IsHiddenExternal;
    bool newHidden  = (bNew  is null) ? true : bNew.IsHiddenExternal;

    log("Variant ui=" + tostring(uiRow)
        + " has Edit:" + (bEdit is null ? "null" : (editHidden ? "hidden" : "visible"))
        + " New:" + (bNew is null ? "null" : (newHidden ? "hidden" : "visible")), LogLevel::Debug, 453, "_ClickVariant");






    if (prefer == "edit") {
        if (bEdit !is null) { bEdit.OnAction(); return true; }
        if (bNew  !is null) { bNew.OnAction();  return true; }
        return false;
    } else if (prefer == "new") {
        if (bNew  !is null) { bNew.OnAction();  return true; }
        if (bEdit !is null) { bEdit.OnAction(); return true; }
        return false;
    } else {
        if (bEdit !is null && !editHidden) { bEdit.OnAction(); return true; }
        if (bNew  !is null && !newHidden)  { bNew.OnAction();  return true; }
        if (bEdit !is null) { bEdit.OnAction(); return true; }
        if (bNew  !is null) { bNew.OnAction();  return true; }
        return false;
    }
}

bool _LooksLikeDefaultCubeWarning(const string &in rawText) {
    string ll = UiNav::NormalizeForCompare(rawText).ToLower();
    bool hasCube = ll.IndexOf("default cube") >= 0;
    bool hasConv = (ll.IndexOf("couldn't be converted") >= 0) || (ll.IndexOf("could not be converted") >= 0) || (ll.IndexOf("couldnt be converted") >= 0);
    bool hasReplace = ll.IndexOf("will replace") >= 0 || ll.IndexOf("replace it") >= 0;
    return hasCube && (hasConv || hasReplace);
}

void _HandleDefaultCubeWarningIfPresent(FlowRun@ run, const string &in blockCanon, const string &in variantLabel) {
    CControlBase@ n = UiNav::ResolvePath(PATH_WARN_LABEL, OVL_WARN_CUBE);
    if (n is null) return;

    string raw = UiNav::ReadText(n);
    if (!_LooksLikeDefaultCubeWarning(raw)) return;

    log("OpenMeshModeller: default-cube warning detected -> clicking OK.", LogLevel::Warn, 492, "_HandleDefaultCubeWarningIfPresent");
    _AppendWarning(run, "mesh_modeller_default_cube", blockCanon, variantLabel, raw);

    UiNav::ClickPath(PATH_WARN_OKBTN, OVL_WARN_CUBE);
    yield();
}

string _GetBlockCanonFromCtxOrIndex(FlowRun@ run) {
    if (run !is null) {
        string b;
        if (run.ctx.GetString("blockName", b) && b.Length > 0) return b;
    }
    return automata::Helpers::Blocks::GetCurrentName();
}

void _MarkSkipped(FlowRun@ run,
                  const string &in reasonTag,
                  const string &in blockCanon,
                  const string &in variantLabel,
                  const string &in humanMsg)
{
    if (run is null) return;

    run.ctx.Set("meshModellerSkipped", "1");
    run.ctx.Set("meshModellerSkipReason", reasonTag);
    run.ctx.Set("meshModellerSkipBlock", blockCanon);
    run.ctx.Set("meshModellerSkipVariant", variantLabel);
    run.ctx.Set("meshModellerOpened", "0");

    _AppendWarning(run, "mesh_modeller_skip", blockCanon, variantLabel, humanMsg);
}

bool _SkipIfDynamicDBSaysSo(FlowRun@ run,
                            bool okOnSkip,
                            const string &in blockCanon,
                            const string &in variantKey)
{
    if (run is null) return okOnSkip;
    if (blockCanon.Length == 0 || variantKey.Length == 0) return false;

    if (!automata::Helpers::VariantSkips::ShouldSkip(blockCanon, variantKey))
        return false;

    string note = automata::Helpers::VariantSkips::GetNoteForBlock(blockCanon);

    string msg = "OpenMeshModeller: SKIP known crash variant '" + variantKey
               + "' for block '" + blockCanon + "'"
               + (note.Length > 0 ? (" | " + note) : "");

    Json::Value@ extra = Json::Object();
    extra["blockName"] = blockCanon;
    extra["variantKey"] = variantKey;
    if (note.Length > 0) extra["note"] = note;

    automata::Helpers::FlowStatus::RecordEvent(run, "warn", "mm.variant_skipped", msg, extra);

    _MarkSkipped(run, "dynamic_skipdb", blockCanon, variantKey, msg);
    run.ctx.lastError = msg;

    return okOnSkip;
}

void _WritePendingAndIntent(FlowRun@ run,
                            const string &in mode,
                            const string &in prefer,
                            const string &in blockCanon,
                            const string &in variantKey)
{
    if (run is null) return;
    if (blockCanon.Length == 0 || variantKey.Length == 0) return;

    
    run.ctx.Set(CTX_MM_PENDING_ACTIVE,  "1");
    run.ctx.Set(CTX_MM_PENDING_BLOCK,   blockCanon);
    run.ctx.Set(CTX_MM_PENDING_VARIANT, variantKey);
    run.ctx.Set(CTX_MM_PENDING_MODE,    mode);
    run.ctx.Set(CTX_MM_PENDING_PREFER,  prefer);

    automata::Helpers::VariantSkips::MarkPending(blockCanon, variantKey, "pending: open_mesh_modeller");    
    automata::Helpers::CrashWatch::WriteIntent(run, "open_mesh_modeller", blockCanon, variantKey);
}

void _ClearPendingAndIntentNonCrash(FlowRun@ run,
                                   const string &in whyTag,
                                   const string &in whyMsg)
{
    if (run !is null) {
        string act = "";
        if (run.ctx.GetString(CTX_MM_PENDING_ACTIVE, act) && act == "1") {
            string blk = "";
            string v   = "";
            run.ctx.GetString(CTX_MM_PENDING_BLOCK, blk);
            run.ctx.GetString(CTX_MM_PENDING_VARIANT, v);

            if (blk.Length > 0 && v.Length > 0) {
                automata::Helpers::VariantSkips::MarkSafeRemove(blk, v, "open_mesh_modeller non-crash failure");
            }

            _ResetPendingCtx(run);
        }
    }

    automata::Helpers::CrashWatch::ClearIntent(whyTag, whyMsg);
}

bool _Open_BlockToBlock(FlowRun@ run,
                        const Json::Value@ args,
                        uint overlay,
                        bool okOnSkip,
                        bool skipIfKnownCrash,
                        const string &in variantKeyArg)
{
    log("OpenMeshModeller: block-to-block overlay=" + tostring(overlay), LogLevel::Info, 604, "_Open_BlockToBlock");

    const string blockCanon = _GetBlockCanonFromCtxOrIndex(run);

    string resolvedPath;
    CControlListCard@ propsLC = _FindPropertiesListCard(overlay, resolvedPath);
    if (propsLC is null) {
        log("open_mesh_modeller (block-to-block): Properties path not found: " + PROPS_ROOT_A + " (BFS fallback also attempted)", LogLevel::Warn, 611, "_Open_BlockToBlock");

        run.ctx.lastError = "open_mesh_modeller (block-to-block): Properties list not found at overlay " + tostring(overlay);
        _ClearPendingAndIntentNonCrash(run, "failed", "Properties list not found (non-crash).");
        return false;
    }
    log("Found ListCardProperties at: " + (resolvedPath.Length == 0 ? "<unknown>" : resolvedPath), LogLevel::Info, 617, "_Open_BlockToBlock");


    array<int> rowUI;
    array<string> labels;
    _CollectVariantRows(propsLC, rowUI, labels);

    if (rowUI.Length == 0) {
        log("open_mesh_modeller (block-to-block): no variant-like rows detected (rows should contain 6/0 or 6/3).", LogLevel::Warn, 625, "_Open_BlockToBlock");

        run.ctx.lastError = "open_mesh_modeller (block-to-block): could not locate variant rows. Are you on the Properties panel?";
        _ClearPendingAndIntentNonCrash(run, "failed", "No variant rows detected (non-crash).");
        return false;
    }

    int pos = _SelectVariantPos(args, rowUI, labels);
    if (pos < 0) {
        run.ctx.lastError = "open_mesh_modeller (block-to-block): could not resolve a variant to open.";
        _ClearPendingAndIntentNonCrash(run, "failed", "Could not resolve variant (non-crash).");
        return false;
    }

    const int uiVariantRow = rowUI[uint(pos)];
    const string variantKeyFromRow = _ExtractVariantKey(labels[uint(pos)]); 
    const string variantLbl = _NormalizeUiLabel(labels[uint(pos)]);

    string vKey = variantKeyFromRow.Length > 0 ? variantKeyFromRow : _ExtractVariantKey(variantKeyArg);
    vKey = vKey.ToLower().Trim();
    string vId = vKey.Length > 0 ? vKey : variantLbl;

    if (skipIfKnownCrash) {        
        string reason;
        if (CrashSkip::ShouldSkip(blockCanon, vId, reason)) {
            string msg = "Skipped Mesh Modeller (CrashSkip): " + blockCanon + " | variant='" + vId + "' | " + reason;
            log(msg, LogLevel::Warn, 651, "_Open_BlockToBlock");
            _MarkSkipped(run, "crash_skiplist", blockCanon, vId, msg);
            run.ctx.lastError = msg;
            return okOnSkip;
        }

        if (vKey.Length > 0) {
            bool retOk = _SkipIfDynamicDBSaysSo(run, okOnSkip, blockCanon, vKey);
            if (retOk || (!retOk && !okOnSkip)) {
                if (automata::Helpers::VariantSkips::ShouldSkip(blockCanon, vKey)) return retOk;
            }
        }
    }
    
    string pref = _ParsePrefer(args, "auto");

    if (blockCanon.Length > 0 && vKey.Length > 0) {
        _WritePendingAndIntent(run, "block-to-block", pref, blockCanon, vKey);
    }

    bool ok = _ClickVariant(propsLC, uiVariantRow, pref);
    if (!ok) {
        run.ctx.lastError = "open_mesh_modeller (block-to-block): failed to click '" + pref + "' on ui row " + tostring(uiVariantRow);
        _ClearPendingAndIntentNonCrash(run, "failed", "Failed to click variant row (non-crash failure).");
        return false;
    }
    
    run.ctx.Set("meshModellerSkipped", "0");
    run.ctx.Set("meshModellerOpened", "1");
    run.ctx.Set("meshModellerVariant", vId);

    yield();
    _HandleDefaultCubeWarningIfPresent(run, blockCanon, vId);

    log("Clicked variant ui=" + tostring(uiVariantRow) + " prefer=" + pref + " key='" + vKey + "' label='" + variantLbl + "'", LogLevel::Info, 685, "_Open_BlockToBlock");

    return true;
}

bool _Open_BlockToItem(FlowRun@ run,
                       const Json::Value@ args,
                       uint overlay,
                       bool okOnSkip,
                       bool skipIfKnownCrash,
                       const string &in variantKeyArg)
{
    const string blockCanon = _GetBlockCanonFromCtxOrIndex(run);
    
    string vKey = _ExtractVariantKey(variantKeyArg).ToLower().Trim();
    string vId = vKey.Length > 0 ? vKey : "";
    
    if (skipIfKnownCrash && blockCanon.Length > 0 && vKey.Length > 0) {
        if (automata::Helpers::VariantSkips::ShouldSkip(blockCanon, vKey)) {
            string note = automata::Helpers::VariantSkips::GetNoteForBlock(blockCanon);
            string msg = "OpenMeshModeller: SKIP known crash variant '" + vKey + "' for block '" + blockCanon + "'" + (note.Length > 0 ? (" | " + note) : "");
            _MarkSkipped(run, "dynamic_skipdb", blockCanon, vKey, msg);
            run.ctx.lastError = msg;
            return okOnSkip;
        }
    }

    if (!UiNav::WaitForPath(BTI_ROOT, overlay, 3000, 33)) {
        run.ctx.lastError = "open_mesh_modeller (block-to-item): UI group not found at overlay " + tostring(overlay);
        _ClearPendingAndIntentNonCrash(run, "failed", "Block-to-item UI group not found (non-crash).");
        return false;
    }

    string pref = _ParsePrefer(args, "edit");
    
    if (blockCanon.Length > 0 && vKey.Length > 0) {
        _WritePendingAndIntent(run, "block-to-item", pref, blockCanon, vKey);
    }

    bool ok = false;
    if (pref == "edit") {
        ok = UiNav::ClickPath(BTI_EDIT, overlay);
    } else if (pref == "new") {
        ok = UiNav::ClickPath(BTI_NEW, overlay);
    } else {
        ok = UiNav::ClickPath(BTI_EDIT, overlay);
        if (!ok) ok = UiNav::ClickPath(BTI_NEW, overlay);
    }
    if (!ok) {
        run.ctx.lastError = "open_mesh_modeller (block-to-item): failed to click '" + pref + "'";
        _ClearPendingAndIntentNonCrash(run, "failed", "Failed to click block-to-item button (non-crash).");
        return false;
    }

    run.ctx.Set("meshModellerSkipped", "0");
    run.ctx.Set("meshModellerOpened", "1");
    if (vId.Length > 0) run.ctx.Set("meshModellerVariant", vId);

    log("OpenMeshModeller: block-to-item prefer=" + pref, LogLevel::Info, 743, "_Open_BlockToItem");

    yield();
    _HandleDefaultCubeWarningIfPresent(run, blockCanon, vId);

    return true;
}

bool Cmd_OpenMeshModeller(FlowRun@ run, Json::Value@ args) {
    string mode = Helpers::Args::ReadLowerStr(args, "mode", "block-to-block");
    if (mode != "block-to-block" && mode != "block-to-item") mode = "block-to-block";

    uint overlay = uint(Helpers::Args::ReadInt(args, "overlay", int(DEFAULT_OVERLAY)));
    
    string blockName = Helpers::Args::ReadStr(args, "blockName", "").Trim();
    if (blockName.Length > 0) run.ctx.Set("blockName", blockName);

    string variantKeyArg = Helpers::Args::ReadFirstStr(args, {"variantKey", "variant"}, "");

    bool okOnSkip = Helpers::Args::ReadBool(args, "okOnSkip", false);
    bool skipIfKnownCrash = Helpers::Args::ReadBool(args, "skipIfKnownCrash", true);
    if (args !is null && args.HasKey("skipIfKnownCrash")) {
        skipIfKnownCrash = Helpers::Args::ReadBool(args, "skipIfKnownCrash", skipIfKnownCrash);
    }
    if (args !is null && args.HasKey("skipIfKnownCrashVariant")) {
        skipIfKnownCrash = Helpers::Args::ReadBool(args, "skipIfKnownCrashVariant", skipIfKnownCrash);
    }

    run.ctx.Set("meshModellerSkipped", "0");
    run.ctx.Set("meshModellerOpened", "0");
    run.ctx.Set("meshModellerVariant", "");

    bool ok = false;
    if (mode == "block-to-item") {
        ok = _Open_BlockToItem(run, args, overlay, okOnSkip, skipIfKnownCrash, variantKeyArg);
    } else {
        ok = _Open_BlockToBlock(run, args, overlay, okOnSkip, skipIfKnownCrash, variantKeyArg);
    }

    return ok;
}

void RegisterOpenMeshModeller(CommandRegistry@ R) {
    R.Register("open_mesh_modeller", CommandFn(Cmd_OpenMeshModeller));
}

}}}
