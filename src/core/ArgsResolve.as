namespace automata {

Json::Value@ JsonDeepClone(Json::Value@ v) {
    if (v is null) return null;
    string s = Json::Write(v);
    return Json::Parse(s);
}

bool _TryGetParam(Json::Value@ params, const string &in path, Json::Value &out outVal) {
    if (params is null) return false;
    array<string> parts = path.Split(".");
    Json::Value@ cur = params;
    for (uint i = 0; i < parts.Length; ++i) {
        string key = parts[i];
        if (cur is null || !cur.HasKey(key)) return false;
        @cur = cur[key];
    }
    outVal = cur;
    return true;
}

bool _IsIdentChar(uint8 c) {
    return ( (c >= 48 && c <= 57)
          || (c >= 65 && c <= 90)
          || (c >= 97 && c <= 122)
          || c == 95
          || c == 46 );
}

string _ReplaceAllVarsInString(const string &in s, RunCtx &in ctx, Json::Value@ params) {
    string sOut = s;

    int pos = 0;
    while ((pos = sOut.IndexOf("$ctx.")) >= 0) {
        int start = pos + 5;
        int end = start;
        while (end < int(sOut.Length) && _IsIdentChar(sOut[end])) end++;
        string key = sOut.SubStr(start, end - start);

        string repl = "";
        if (ctx.kv.Exists(key)) repl = string(ctx.kv[key]);

        sOut = sOut.SubStr(0, pos) + repl + sOut.SubStr(end);
    }

    while ((pos = sOut.IndexOf("$params.")) >= 0) {
        int start = pos + 8;
        int end = start;
        while (end < int(sOut.Length) && _IsIdentChar(sOut[end])) end++;
        string path = sOut.SubStr(start, end - start);

        string repl = "";
        Json::Value tmp;
        if (_TryGetParam(params, path, tmp)) {
            if (tmp.GetType() == Json::Type::String) repl = string(tmp);
            else repl = Json::Write(tmp);
        }
        sOut = sOut.SubStr(0, pos) + repl + sOut.SubStr(end);
    }
    return sOut;
}

Json::Value@ ResolveArgs(Json::Value@ inArgs, RunCtx &in ctx, Json::Value@ params) {
    if (inArgs is null) return Json::Object();

    auto t = inArgs.GetType();
    if (t == Json::Type::String) {
        string raw = string(inArgs);

        if (raw.StartsWith("$params.") && raw.IndexOf(" ") < 0 && raw.IndexOf("\"") < 0) {
            string path = raw.SubStr(8);
            Json::Value pv;
            if (_TryGetParam(params, path, pv)) {
                return JsonDeepClone(@pv);
            }
        }

        string rep = _ReplaceAllVarsInString(raw, ctx, params);
        Json::Value tmp; tmp = rep;
        string json = Json::Write(tmp);
        return Json::Parse(json);
    } else if (t == Json::Type::Array) {
        Json::Value@ arr = Json::Array();
        for (uint i = 0; i < inArgs.Length; ++i) {
            arr.Add(ResolveArgs(inArgs[i], ctx, params));
        }
        return arr;
    } else if (t == Json::Type::Object) {
        Json::Value@ obj = Json::Object();
        array<string>@ keys = inArgs.GetKeys();
        for (uint i = 0; i < keys.Length; ++i) {
            string k = keys[i];
            obj[k] = ResolveArgs(inArgs[k], ctx, params);
        }
        return obj;
    }
    return inArgs;
}

}
