namespace UiNav {

    CControlFrame@ RootAtOverlay(uint overlay = 16) {
        CGameCtnApp@ app = GetApp();
        if (app is null || app.Viewport is null) return null;

        CDx11Viewport@ vp = cast<CDx11Viewport>(app.Viewport);
        if (vp is null) return null;
        if (overlay >= vp.Overlays.Length) return null;

        CHmsZoneOverlay@ ov = cast<CHmsZoneOverlay>(vp.Overlays[overlay]);
        if (ov is null || ov.UserData is null) return null;

        CSceneSector@ sector = cast<CSceneSector>(ov.UserData);
        if (sector is null || sector.Scene is null) return null;

        CScene2d@ scene = cast<CScene2d>(sector.Scene);
        if (scene.Mobils.Length == 0 || scene.Mobils[0] is null) return null;

        CControlFrameStyled@ rootStyled = cast<CControlFrameStyled>(scene.Mobils[0]);
        if (rootStyled !is null) return cast<CControlFrame>(rootStyled);

        return cast<CControlFrame>(scene.Mobils[0]);
    }

    bool _GetScene2d(uint overlay, CScene2d@ &out scene) {
        @scene = null;
        CGameCtnApp@ app = GetApp();
        if (app is null || app.Viewport is null) return false;

        CDx11Viewport@ vp = cast<CDx11Viewport>(app.Viewport);
        if (vp is null) return false;
        if (overlay >= vp.Overlays.Length) return false;

        CHmsZoneOverlay@ ov = cast<CHmsZoneOverlay>(vp.Overlays[overlay]);
        if (ov is null || ov.UserData is null) return false;

        CSceneSector@ sector = cast<CSceneSector>(ov.UserData);
        if (sector is null || sector.Scene is null) return false;

        @scene = cast<CScene2d>(sector.Scene);
        return scene !is null;
    }

    CControlFrame@ _RootFromMobil(CScene2d@ scene, uint mobilIx) {
        if (scene is null || mobilIx >= scene.Mobils.Length) return null;

        CControlFrameStyled@ rootStyled = cast<CControlFrameStyled>(scene.Mobils[mobilIx]);
        if (rootStyled !is null) return cast<CControlFrame>(rootStyled);

        return cast<CControlFrame>(scene.Mobils[mobilIx]);
    }


    uint _ChildrenLen(CControlBase@ node) {
        if (node is null) return 0;

        CControlFrame@ f = cast<CControlFrame>(node);
        if (f !is null) return f.Childs.Length;

        CControlListCard@ lc = cast<CControlListCard>(node);
        if (lc !is null) return lc.Childs.Length;

        CControlGrid@ g = cast<CControlGrid>(node);
        if (g !is null) return g.Childs.Length;

        return 0;
    }

    CControlBase@ _ChildAt(CControlBase@ node, uint idx) {
        if (node is null) return null;

        CControlFrame@ f = cast<CControlFrame>(node);
        if (f !is null) { if (idx < f.Childs.Length) return f.Childs[idx]; return null; }

        CControlListCard@ lc = cast<CControlListCard>(node);
        if (lc !is null) { if (idx < lc.Childs.Length) return lc.Childs[idx]; return null; }

        CControlGrid@ g = cast<CControlGrid>(node);
        if (g !is null) { if (idx < g.Childs.Length) return g.Childs[idx]; return null; }

        return null;
    }


    string ReadText(CControlBase@ n) {
        if (n is null) return "";

        CControlEntry@ e = cast<CControlEntry>(n);
        if (e !is null) return e.String;

        CControlFrame@ f = cast<CControlFrame>(n);
        if (f !is null) {
            CControlEntry@ e2 = cast<CControlEntry>(f.Nod);
            if (e2 !is null) return e2.String;
        }

        CControlLabel@ lbl = cast<CControlLabel>(n);
        if (lbl !is null) return lbl.Label;

        return "";
    }

    string CleanUiFormatting(const string &in s) {
        string r = s;
        r = r.Replace("/", "/");
        r = r.Replace("", "");
        r = r.Replace("", "");
        r = r.Replace("\\", "/");
        return r;
    }

    string NormalizeForCompare(const string &in s) {
        string r = CleanUiFormatting(s);
        r = r.Replace("%1", "").Replace("%2", "").Replace("%3", "");
        r = r.Trim();
        return r;
    }

    string NodeTypeName(CControlBase@ n) {
        if (n is null) return "null";
        if (cast<CControlLabel>(n) !is null) return "Label";
        if (cast<CControlEntry>(n) !is null) return "Entry";
        if (cast<CControlButton>(n) !is null) return "Button";
        if (cast<CControlQuad>(n) !is null) return "Quad";
        if (cast<CControlListCard>(n) !is null) return "ListCard";
        if (cast<CControlGrid>(n) !is null) return "Grid";
        if (cast<CControlFrameStyled>(n) !is null) return "FrameStyled";
        if (cast<CControlFrame>(n) !is null) return "Frame";
        if (cast<CGameControlCardGeneric>(n) !is null) return "CardGeneric";
        return "Control";
    }

    class _NodeQ {
        CControlBase@ n;
        string path;
        uint depth;
    }
}