namespace automata { namespace Helpers { namespace Args {

bool ReadBool(Json::Value@ args, const string &in key, bool defVal) {
    if (args is null || !args.HasKey(key)) return defVal;
    auto v = args[key];
    auto t = v.GetType();
    if (t == Json::Type::Boolean) return bool(v);
    if (t == Json::Type::String) {
        string s = string(v).ToLower().Trim();
        if (s == "true" || s == "1" || s == "yes" || s == "y" || s == "on")  return true;
        if (s == "false"|| s == "0" || s == "no"  || s == "n" || s == "off") return false;
        return defVal;
    }
    try { return int(v) != 0; } catch {}
    try { return float(v) != 0.0f; } catch {}
    return defVal;
}

int ReadInt(Json::Value@ args, const string &in key, int defVal) {
    if (args is null || !args.HasKey(key)) return defVal;
    Json::Value@ v = args[key];
    try { return int(v); } catch {}
    try {
        string s = string(v).Trim();
        if (s.Length > 0) {
            int tmp; bool ok = false;
            try { ok = Text::TryParseInt(s, tmp); } catch {}
            if (ok) return tmp;
            try { return Text::ParseInt(s); } catch {}
        }
    } catch {}
    try { return bool(v) ? 1 : 0; } catch {}
    return defVal;
}

int ReadIntClamped(Json::Value@ args, const string &in key, int defVal, int minVal, int maxVal) {
    int v = ReadInt(args, key, defVal);
    if (v < minVal) return minVal;
    if (v > maxVal) return maxVal;
    return v;
}

string ReadStr(Json::Value@ args, const string &in key, const string &in defVal) {
    if (args is null || !args.HasKey(key)) return defVal;
    auto v = args[key];
    if (v.GetType() == Json::Type::String) return string(v);
    try { return string(v); } catch {}
    return defVal;
}

string ReadLowerStr(Json::Value@ args, const string &in key, const string &in defVal) {
    return ReadStr(args, key, defVal).ToLower().Trim();
}

string ReadFirstStr(Json::Value@ args, const array<string> &in keys, const string &in defVal) {
    if (args is null) return defVal;
    for (uint i = 0; i < keys.Length; ++i) {
        string k = keys[i];
        if (!args.HasKey(k)) continue;
        string s = "";
        try { s = string(args[k]); } catch { continue; }
        s = s.Trim();
        if (s.Length > 0) return s;
    }
    return defVal;
}

}}}
