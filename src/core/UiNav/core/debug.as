namespace UiNav {
    void DumpOverlay(uint overlay = 16, int maxDepth = 5) {
        CScene2d@ scene;
        if (!_GetScene2d(overlay, scene)) { log("DumpOverlay: no scene for overlay " + overlay, LogLevel::Debug, 4, "DumpOverlay"); return; }
        for (uint i = 0; i < scene.Mobils.Length; i++) {
            CControlFrame@ r = _RootFromMobil(scene, i);
            if (r is null) continue;
            _DumpSubtree(r, "root[" + i + "]", 0, maxDepth);
        }
    }

    void _DumpSubtree(CControlBase@ n, const string &in path, int depth, int maxDepth) {
        if (n is null || depth > maxDepth) return;

        string t = ReadText(n);
        if (t.Length > 0) {
            string shortT = t; if (shortT.Length > 160) shortT = shortT.SubStr(0, 160) + "...";
            trace(path + " : " + NodeTypeName(n) + " : \"" + CleanUiFormatting(shortT) + "\"");
        } else {
            trace(path + " : " + NodeTypeName(n));
        }

        uint len = _ChildrenLen(n);
        for (uint i = 0; i < len; i++) {
            _DumpSubtree(_ChildAt(n, i), path + "/" + i, depth + 1, maxDepth);
        }
    }
}