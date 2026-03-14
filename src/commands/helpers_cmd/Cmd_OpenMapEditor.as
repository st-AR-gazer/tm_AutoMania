namespace automata { namespace Helpers { namespace OpenMapEditor {

string _ArgString(Json::Value@ args, const string &in key, const string &in def) {
    if (args is null || !args.HasKey(key)) return def;
    if (args[key].GetType() == Json::Type::String) return string(args[key]);
    return Json::Write(args[key]);
}

bool _ArgBool(Json::Value@ args, const string &in key, bool def) {
    if (args is null || !args.HasKey(key)) return def;
    auto t = args[key].GetType();
    if (t == Json::Type::Boolean) return bool(args[key]);
    if (t == Json::Type::Number)  return int(args[key]) != 0;
    if (t == Json::Type::String) {
        string s = string(args[key]).ToLower().Trim();
        if (s == "true" || s == "1" || s == "yes" || s == "y") return true;
        if (s == "false" || s == "0" || s == "no" || s == "n") return false;
    }
    return def;
}

uint _ArgUInt(Json::Value@ args, const string &in key, uint def) {
    if (args is null || !args.HasKey(key)) return def;
    auto t = args[key].GetType();
    if (t == Json::Type::Number) return uint(args[key]);
    if (t == Json::Type::String) {
        int v = Text::ParseInt(string(args[key]).Trim());
        if (v >= 0) return uint(v);
    }
    return def;
}

bool _ShouldAbort(FlowRun@ run) { return run !is null && run.ctx.cancelled; }

string _EditorTypeStr(CGameManiaPlanet@ app) {
    if (app is null || app.Editor is null) return "null";
    return app.Editor.IdName;
}

bool _IsAnyEditorOpen(CGameManiaPlanet@ app) {
    return app !is null && app.Editor !is null;
}

bool _IsAdvancedEditorReady(CGameManiaPlanet@ app) {
    if (app is null) return false;
    auto ed = cast<CGameCtnEditorFree>(app.Editor);
    if (ed is null) return false;
    return ed.PluginMapType !is null;
}

bool _IsRequestedEditorReady(CGameManiaPlanet@ app, bool useSimpleEditor) {
    if (useSimpleEditor) return _IsAnyEditorOpen(app);
    return _IsAdvancedEditorReady(app);
}

bool _HasTrackmaniaMenus(CGameManiaPlanet@ app) {
    if (app is null || app.Switcher is null) return false;
    for (uint i = 0; i < app.Switcher.ModuleStack.Length; ++i) {
        if (cast<CTrackManiaMenus>(app.Switcher.ModuleStack[i]) !is null) return true;
    }
    return false;
}

void _LogApiResult(CGameManiaPlanet@ app, const string &in ctx) {
    if (app is null) return;
    auto api = app.ManiaTitleControlScriptAPI;
    log("OpenMapEditor: " + ctx
        + " | TitleAPI.IsReady=" + tostring(api.IsReady)
        + " LatestResult=" + tostring(int(api.LatestResult))
        + " CustomResultType='" + string(api.CustomResultType) + "'"
        + " CustomResultDataLen=" + tostring(api.CustomResultData.Length), LogLevel::Debug, 67, "_LogApiResult");









}

bool _ReturnToMenuAndWaitReady(FlowRun@ run, CGameManiaPlanet@ app, uint timeoutMs, bool closeInGameMenu) {
    uint t0 = Time::Now;
    uint nextLog = t0 + 5000;

    if (app is null) return false;

    if (closeInGameMenu) {
        try {
            if (app.Network !is null
                && app.Network.PlaygroundClientScriptAPI !is null
                && app.Network.PlaygroundClientScriptAPI.IsInGameMenuDisplayed)
            {
                if (app.Network.PlaygroundInterfaceScriptHandler !is null) {
                    log("OpenMapEditor: in-game menu displayed -> closing with Quit.", LogLevel::Info, 92, "_ReturnToMenuAndWaitReady");
                    app.Network.PlaygroundInterfaceScriptHandler.CloseInGameMenu(
                        CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Quit
                    );
                    yield();
                }
            }
        } catch { }
    }

    app.BackToMainMenu();

    while (true) {
        if (_ShouldAbort(run)) return false;

        bool apiReady = app.ManiaTitleControlScriptAPI.IsReady;
        bool menusOk = _HasTrackmaniaMenus(app);

        if (apiReady && menusOk) break;

        if (Time::Now - t0 > timeoutMs) {
            run.ctx.lastError = "open_map_editor: timed out waiting for main menu readiness (Title API + menus).";
            log(run.ctx.lastError, LogLevel::Warn, 114, "_ReturnToMenuAndWaitReady");
            return false;
        }

        if (Time::Now >= nextLog) {
            log("OpenMapEditor: waiting for menu readiness..."
                + " TitleAPI.IsReady=" + tostring(apiReady)
                + " HasMenus=" + tostring(menusOk), LogLevel::Debug, 119, "_ReturnToMenuAndWaitReady");





            nextLog = Time::Now + 5000;
        }

        yield(100);
    }
    
    yield();
    yield(250);
    return true;
}

bool _WaitForRequestedEditor(FlowRun@ run, CGameManiaPlanet@ app, uint timeoutMs, bool useSimpleEditor, const string &in phaseTag) {
    uint t0 = Time::Now;
    uint nextLog = t0 + 5000;

    while (!_IsRequestedEditorReady(app, useSimpleEditor)) {
        if (_ShouldAbort(run)) return false;

        if (Time::Now - t0 > timeoutMs) {
            run.ctx.lastError = "open_map_editor: timed out waiting for editor ready after " + phaseTag
                + " (Editor=" + _EditorTypeStr(app) + ").";
            log(run.ctx.lastError, LogLevel::Warn, 146, "_WaitForRequestedEditor");
            return false;
        }

        if (Time::Now >= nextLog) {
            log("OpenMapEditor: waiting for editor..."
                + " phase=" + phaseTag
                + " requested=" + (useSimpleEditor ? "simple" : "advanced")
                + " currentEditor=" + _EditorTypeStr(app), LogLevel::Debug, 151, "_WaitForRequestedEditor");







            _LogApiResult(app, "progress");
            nextLog = Time::Now + 5000;
        }

        yield(100);
    }

    return true;
}

bool _StartNewMapViaEditNewMap2(FlowRun@ run, CGameManiaPlanet@ app, Json::Value@ args, uint timeoutMs) {
    string env         = _ArgString(args, "environment", "Stadium");
    string decor       = _ArgString(args, "decoration", "");
    if (decor.Length == 0) decor = _ArgString(args, "mood", "48x48Screen155Day");
    if (decor.Length == 0) decor = "48x48Screen155Day";

    string modNameOrUrl = _ArgString(args, "modNameOrUrl", "");
    string playerModel  = _ArgString(args, "playerModel", "CarSport");

    string mapType      = _ArgString(args, "mapType", "TrackMania\\TM_Race");
    bool useSimple      = _ArgBool(args, "useSimpleEditor", false);

    string pluginScript = _ArgString(args, "editorPluginScript", "");
    string pluginArg    = _ArgString(args, "editorPluginArgument", "");
    
    array<string> mapTypes;
    mapTypes.InsertLast(mapType);
    if (mapType.IndexOf("Trackmania\\") == 0) mapTypes.InsertLast(mapType.Replace("Trackmania\\", "TrackMania\\"));
    else if (mapType.IndexOf("TrackMania\\") == 0) mapTypes.InsertLast(mapType.Replace("TrackMania\\", "Trackmania\\"));

    for (uint i = 0; i < mapTypes.Length; ++i) {
        string mt = mapTypes[i];

        log("OpenMapEditor: EditNewMap2("
            + "env='" + env
            + "', decor='" + decor
            + "', mod='" + modNameOrUrl
            + "', playerModel='" + playerModel
            + "', mapType='" + mt
            + "', useSimple=" + tostring(useSimple)
            + ")", LogLevel::Info, 192, "_StartNewMapViaEditNewMap2");
















        app.ManiaTitleControlScriptAPI.EditNewMap2(
            env,
            decor,
            wstring(modNameOrUrl),  
            wstring(playerModel),   
            wstring(mt),            
            useSimple,              
            wstring(pluginScript),  
            pluginArg               
        );

        yield();
        yield(250);
        _LogApiResult(app, "after EditNewMap2 #" + tostring(i + 1));

        if (_WaitForRequestedEditor(run, app, timeoutMs, useSimple, "EditNewMap2(" + mt + ")")) return true;
        
        if (i + 1 < mapTypes.Length) {
            log("OpenMapEditor: EditNewMap2 attempt failed; retrying with alternate MapType casing.", LogLevel::Warn, 227, "_StartNewMapViaEditNewMap2");
            if (!_ReturnToMenuAndWaitReady(run, app, timeoutMs, true)) return false;
            if (_ShouldAbort(run)) return false;
        }
    }

    return false;
}

bool Cmd_OpenMapEditor(FlowRun@ run, Json::Value@ args) {
    if (run is null) return false;

    if (!Permissions::OpenAdvancedMapEditor()) {
        run.ctx.lastError = "open_map_editor: missing permission Permissions::OpenAdvancedMapEditor().";
        log(run.ctx.lastError, LogLevel::Error, 241, "Cmd_OpenMapEditor");
        return false;
    }

    auto app = cast<CGameManiaPlanet>(GetApp());
    if (app is null) {
        run.ctx.lastError = "open_map_editor: GetApp() is not a CGameManiaPlanet.";
        log(run.ctx.lastError, LogLevel::Error, 248, "Cmd_OpenMapEditor");
        return false;
    }

    uint timeoutMs       = _ArgUInt(args, "timeoutMs", 180000);
    bool backToMenu      = _ArgBool(args, "backToMenu", true);
    bool closeInGameMenu = _ArgBool(args, "closeInGameMenu", true);
    bool forceNewMap     = _ArgBool(args, "forceNewMap", false);

    if (_IsAnyEditorOpen(app) && !forceNewMap) {
        log("OpenMapEditor: already in an editor (Editor=" + _EditorTypeStr(app) + "); not forcing a new map.", LogLevel::Info, 258, "Cmd_OpenMapEditor");

        return true;
    }

    log("OpenMapEditor: start (EditNewMap2 only)"
        + " timeoutMs=" + tostring(timeoutMs)
        + " backToMenu=" + tostring(backToMenu)
        + " closeInGameMenu=" + tostring(closeInGameMenu)
        + " forceNewMap=" + tostring(forceNewMap), LogLevel::Info, 263, "Cmd_OpenMapEditor");









    
    if (backToMenu) {
        if (!_ReturnToMenuAndWaitReady(run, app, timeoutMs, closeInGameMenu)) {
            if (_ShouldAbort(run)) return true;
            return false;
        }
    } else {
        if (!_HasTrackmaniaMenus(app) || !app.ManiaTitleControlScriptAPI.IsReady) {
            if (!_ReturnToMenuAndWaitReady(run, app, timeoutMs, closeInGameMenu)) {
                if (_ShouldAbort(run)) return true;
                return false;
            }
        }
    }

    if (_ShouldAbort(run)) return true;
    bool ok = _StartNewMapViaEditNewMap2(run, app, args, timeoutMs);
    if (_ShouldAbort(run)) return true;

    if (ok) {
        log("OpenMapEditor: success.", LogLevel::Info, 293, "Cmd_OpenMapEditor");
        return true;
    }

    if (run.ctx.lastError.Length == 0) run.ctx.lastError = "open_map_editor: failed to open editor (unknown reason).";
    log("OpenMapEditor: FAILED. lastError=" + run.ctx.lastError, LogLevel::Error, 298, "Cmd_OpenMapEditor");
    return false;
}

void RegisterOpenMapEditor(CommandRegistry@ R) {
    R.Register("open_map_editor", CommandFn(Cmd_OpenMapEditor));
}

}}}