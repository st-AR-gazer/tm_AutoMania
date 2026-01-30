namespace automata { namespace Helpers { namespace VariantSkips {

const string kDbFileName = "variants.skip.json";

string gDbPath = "";
bool gLoaded = false;
Json::Value@ gDb = null;

uint gLastVacuumAtMs = 0;

int _NowMs() { return int(Time::Now); }

string _Trim(const string &in s) { return s.Trim(); }

string _NormVariantKey(const string &in v) {
    return v.ToLower().Trim();
}

string _NormBlockCanon(const string &in b) {
    string key = b.Trim();
    string ll = key.ToLower();
    if (ll.EndsWith("customblock") && key.Length > 9) {
        key = key.SubStr(0, key.Length - 9).Trim();
    }
    return key;
}

string _ResolveDbPath() {
    if (gDbPath.Length > 0) return gDbPath;

    string pStorage = IO::FromStorageFolder(kDbFileName);
    if (IO::FileExists(pStorage)) { gDbPath = pStorage; return gDbPath; }

    string pUser = IO::FromUserGameFolder(kDbFileName);
    if (IO::FileExists(pUser)) { gDbPath = pUser; return gDbPath; }

    string pCfg = IO::FromUserGameFolder("Config/" + kDbFileName);
    if (IO::FileExists(pCfg)) { gDbPath = pCfg; return gDbPath; }

    gDbPath = pStorage;
    return gDbPath;
}

void _EnsureDbFolderExists() {
    string dir = IO::FromStorageFolder("");
    if (!IO::FolderExists(dir)) IO::CreateFolder(dir, true);
}

Json::Value@ _EmptyDb() {
    return Json::Object();
}

void _EnsureLoaded() {
    if (gLoaded) return;
    gLoaded = true;

    _EnsureDbFolderExists();
    string path = _ResolveDbPath();

    @gDb = _EmptyDb();

    if (!IO::FileExists(path)) {
        return;
    }

    string raw = "";
    try {
        raw = IO::ReadFile(path);
    } catch {
        log("VariantSkips: failed reading DB at: " + path, LogLevel::Warn, 70, "_EnsureLoaded");
        return;
    }

    raw = raw.Trim();
    if (raw.Length == 0) return;

    try {
        Json::Value@ parsed = Json::Parse(raw);
        if (parsed !is null && parsed.GetType() == Json::Type::Object) {
            @gDb = parsed;
            return;
        }
        log("VariantSkips: DB parsed but root is not an object. Resetting to empty.", LogLevel::Warn, 83, "_EnsureLoaded");
    } catch {
        log("VariantSkips: JSON parse failed. Resetting to empty.", LogLevel::Warn, 85, "_EnsureLoaded");
    }

    @gDb = _EmptyDb();
}

bool _SaveDb(bool pretty) {
    _EnsureLoaded();
    if (gDb is null) @gDb = _EmptyDb();

    string path = _ResolveDbPath();
    string txt = "";
    try {
        txt = Json::Write(gDb, pretty);
    } catch {
        log("VariantSkips: Json::Write failed; not saving.", LogLevel::Error, 100, "_SaveDb");
        return false;
    }

    try {
        IO::WriteFile(path, txt + "\n");
        return true;
    } catch {
        log("VariantSkips: failed writing DB at: " + path, LogLevel::Error, 108, "_SaveDb");
        return false;
    }
}

Json::Value@ _GetBlockNode(const string &in blockCanon, bool createIfMissing) {
    _EnsureLoaded();
    if (gDb is null) @gDb = _EmptyDb();

    string blk = _NormBlockCanon(blockCanon);
    if (blk.Length == 0) return null;

    if (!gDb.HasKey(blk)) {
        if (!createIfMissing) return null;

        Json::Value@ b = Json::Object();
        b["variants"] = Json::Object();
        b["updatedAtMs"] = _NowMs();
        gDb[blk] = b;
    }

    Json::Value@ bNode = gDb[blk];
    if (bNode is null || bNode.GetType() != Json::Type::Object) {
        if (!createIfMissing) return null;
        Json::Value@ nb = Json::Object();
        nb["variants"] = Json::Object();
        nb["updatedAtMs"] = _NowMs();
        gDb[blk] = nb;
        @bNode = gDb[blk];
    }

    if (!bNode.HasKey("variants") || bNode["variants"] is null || bNode["variants"].GetType() != Json::Type::Object) {
        if (createIfMissing) bNode["variants"] = Json::Object();
    }

    return bNode;
}

Json::Value@ _GetVariantsObj(Json::Value@ blockNode, bool createIfMissing) {
    if (blockNode is null) return null;
    if (!blockNode.HasKey("variants") || blockNode["variants"] is null || blockNode["variants"].GetType() != Json::Type::Object) {
        if (!createIfMissing) return null;
        blockNode["variants"] = Json::Object();
    }
    return blockNode["variants"];
}

string _GetState(Json::Value@ vNode) {
    if (vNode is null || vNode.GetType() != Json::Type::Object) return "";
    if (!vNode.HasKey("state")) return "";
    try { return string(vNode["state"]).ToLower().Trim(); } catch {}
    return "";
}

int _CountLinesFast(const string &in s) {
    if (s.Length == 0) return 0;
    int lines = 1;
    for (uint i = 0; i < s.Length; ++i) {
        if (s[i] == 10) lines++;
    }
    return lines;
}

void _Stats(int &out blocks, int &out variants) {
    blocks = 0;
    variants = 0;

    _EnsureLoaded();
    if (gDb is null || gDb.GetType() != Json::Type::Object) return;

    string[] bKeys = gDb.GetKeys();
    blocks = int(bKeys.Length);

    for (uint i = 0; i < bKeys.Length; ++i) {
        Json::Value@ b = gDb[bKeys[i]];
        if (b is null || b.GetType() != Json::Type::Object) continue;
        Json::Value@ vars = b.HasKey("variants") ? b["variants"] : null;
        if (vars is null || vars.GetType() != Json::Type::Object) continue;
        variants += int(vars.GetKeys().Length);
    }
}

bool ShouldSkip(const string &in blockCanon, const string &in variantKeyIn) {
    _EnsureLoaded();
    if (gDb is null) return false;

    string blk = _NormBlockCanon(blockCanon);
    string vKey = _NormVariantKey(variantKeyIn);
    if (blk.Length == 0 || vKey.Length == 0) return false;

    if (!gDb.HasKey(blk)) return false;

    Json::Value@ b = gDb[blk];
    if (b is null || b.GetType() != Json::Type::Object) return false;

    Json::Value@ vars = b.HasKey("variants") ? b["variants"] : null;
    if (vars is null || vars.GetType() != Json::Type::Object) return false;

    if (!vars.HasKey(vKey)) return false;

    string st = _GetState(vars[vKey]);
    return (st == "crash" || st == "pending");
}

string GetNoteForBlock(const string &in blockCanon) {
    _EnsureLoaded();
    if (gDb is null) return "";

    string blk = _NormBlockCanon(blockCanon);
    if (blk.Length == 0 || !gDb.HasKey(blk)) return "";

    Json::Value@ b = gDb[blk];
    if (b is null || b.GetType() != Json::Type::Object) return "";

    if (b.HasKey("note")) {
        try { return string(b["note"]); } catch {}
    }

    Json::Value@ vars = b.HasKey("variants") ? b["variants"] : null;
    if (vars is null || vars.GetType() != Json::Type::Object) return "";

    string[] vKeys = vars.GetKeys();
    for (uint i = 0; i < vKeys.Length; ++i) {
        Json::Value@ v = vars[vKeys[i]];
        if (_GetState(v) != "crash") continue;
        if (v !is null && v.GetType() == Json::Type::Object && v.HasKey("note")) {
            try { return string(v["note"]); } catch {}
        }
    }

    return "";
}

void MarkPending(const string &in blockCanon, const string &in variantKeyIn, const string &in note) {
    _EnsureLoaded();
    if (gDb is null) @gDb = _EmptyDb();

    string blk = _NormBlockCanon(blockCanon);
    string vKey = _NormVariantKey(variantKeyIn);
    if (blk.Length == 0 || vKey.Length == 0) return;

    Json::Value@ b = _GetBlockNode(blk, true);
    Json::Value@ vars = _GetVariantsObj(b, true);
    if (vars is null) return;

    Json::Value@ v = Json::Object();
    v["state"] = "pending";
    v["note"] = note;
    v["tMs"] = _NowMs();
    vars[vKey] = v;

    b["updatedAtMs"] = _NowMs();

    
    _SaveDb(false);
}

void MarkCrash(const string &in blockCanon, const string &in variantKeyIn, const string &in note) {
    _EnsureLoaded();
    if (gDb is null) @gDb = _EmptyDb();

    string blk = _NormBlockCanon(blockCanon);
    string vKey = _NormVariantKey(variantKeyIn);
    if (blk.Length == 0 || vKey.Length == 0) return;

    Json::Value@ b = _GetBlockNode(blk, true);
    Json::Value@ vars = _GetVariantsObj(b, true);
    if (vars is null) return;

    Json::Value@ v = Json::Object();
    v["state"] = "crash";
    v["note"] = note;
    v["tMs"] = _NowMs();
    vars[vKey] = v;

    b["updatedAtMs"] = _NowMs();

    _SaveDb(false);
}

void MarkCrashed(const string &in blockCanon, const string &in variantKeyIn, const string &in note) { MarkCrash(blockCanon, variantKeyIn, note); }
void MarkKnownCrash(const string &in blockCanon, const string &in variantKeyIn, const string &in note) { MarkCrash(blockCanon, variantKeyIn, note); }

bool MarkSafeRemove(const string &in blockCanon, const string &in variantKeyIn, const string &in note) {
    _EnsureLoaded();
    if (gDb is null) return false;

    string blk = _NormBlockCanon(blockCanon);
    string vKey = _NormVariantKey(variantKeyIn);
    if (blk.Length == 0 || vKey.Length == 0) return false;

    if (!gDb.HasKey(blk)) return false;

    Json::Value@ b = gDb[blk];
    if (b is null || b.GetType() != Json::Type::Object) return false;

    Json::Value@ vars = b.HasKey("variants") ? b["variants"] : null;
    if (vars is null || vars.GetType() != Json::Type::Object) return false;

    if (!vars.HasKey(vKey)) return false;

    vars.Remove(vKey);

    if (vars.GetKeys().Length == 0) {
        gDb.Remove(blk);
    } else {
        b["updatedAtMs"] = _NowMs();
    }

    _SaveDb(false);
    return true;
}

bool ClearPending(const string &in blockCanon, const string &in variantKeyIn) {
    return MarkSafeRemove(blockCanon, variantKeyIn, "clear_pending");
}

void AutoVacuumIfNeeded(int maxLines, int targetLines) {
    uint now = Time::Now;
    if (gLastVacuumAtMs != 0 && now - gLastVacuumAtMs < 2000) return;

    string path = _ResolveDbPath();
    if (!IO::FileExists(path)) return;

    string raw;
    try { raw = IO::ReadFile(path); } catch { return; }

    int lines = _CountLinesFast(raw);
    if (lines <= maxLines) return;

    int rmBlocks = 0, rmVars = 0, beforeB = 0, beforeV = 0, afterB = 0, afterV = 0;
    string summary;
    CleanupNow(true, true, false, rmBlocks, rmVars, beforeB, beforeV, afterB, afterV, summary);

    gLastVacuumAtMs = Time::Now;

    log("VariantSkips: AutoVacuum ran. " + summary, LogLevel::Info, 344, "AutoVacuumIfNeeded");
}

bool CleanupNow(bool purgeNonCrash,
                bool minify,
                bool dryRun,
                int &out removedBlocks,
                int &out removedVariants,
                int &out beforeBlocks,
                int &out beforeVariants,
                int &out afterBlocks,
                int &out afterVariants,
                string &out summary)
{
    removedBlocks = 0;
    removedVariants = 0;
    beforeBlocks = 0; beforeVariants = 0;
    afterBlocks = 0;  afterVariants = 0;
    summary = "";

    _EnsureLoaded();
    if (gDb is null || gDb.GetType() != Json::Type::Object) @gDb = _EmptyDb();

    _Stats(beforeBlocks, beforeVariants);

    string[] bKeys = gDb.GetKeys();

    for (uint bi = 0; bi < bKeys.Length; ++bi) {
        string blk = bKeys[bi];
        Json::Value@ b = gDb[blk];
        if (b is null || b.GetType() != Json::Type::Object) {
            gDb.Remove(blk);
            removedBlocks++;
            continue;
        }

        Json::Value@ vars = b.HasKey("variants") ? b["variants"] : null;
        if (vars is null || vars.GetType() != Json::Type::Object) {
            gDb.Remove(blk);
            removedBlocks++;
            continue;
        }

        string[] vKeys = vars.GetKeys();
        for (uint vi = 0; vi < vKeys.Length; ++vi) {
            string vk = vKeys[vi];
            Json::Value@ vNode = vars[vk];
            string st = _GetState(vNode);

            bool keep = true;
            if (purgeNonCrash) {
                keep = (st == "crash");
            }

            if (!keep) {
                vars.Remove(vk);
                removedVariants++;
            }
        }

        if (vars.GetKeys().Length == 0) {
            gDb.Remove(blk);
            removedBlocks++;
        }
    }

    _Stats(afterBlocks, afterVariants);

    summary =
        "before: blocks=" + tostring(beforeBlocks) + " variants=" + tostring(beforeVariants)
      + " | removed: blocks=" + tostring(removedBlocks) + " variants=" + tostring(removedVariants)
      + " | after: blocks=" + tostring(afterBlocks) + " variants=" + tostring(afterVariants)
      + (dryRun ? " | (dryRun)" : "");

    if (dryRun) return true;

    bool ok = _SaveDb(!minify);
    if (!ok) {
        summary += " | save FAILED";
        return false;
    }
    return true;
}

string GetDbPath() {
    return _ResolveDbPath();
}

}}}
