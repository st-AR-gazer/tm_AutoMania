namespace UiNav {

    CControlBase@ ResolvePath(const string &in spec, uint overlay = 16, CControlBase@ start = null) {
        CControlBase@ cur = start;
        if (cur is null) {
            CControlFrame@ root = RootAtOverlay(overlay);
            if (root is null) return null;
            @cur = root;
        }

        array<int> parts;
        array<bool> wc;
        array<array<int>> hints;
        
        _ParsePathEx(spec, parts, wc, hints);

        for (uint i = 0; i < parts.Length; ++i) {
            if (!wc[i]) {
                int k = parts[i]; if (k < 0) return null;
                uint uk = uint(k), len = _ChildrenLen(cur);
                if (uk >= len) return null;
                CControlBase@ ch = _ChildAt(cur, uk); if (ch is null) return null;
                @cur = ch;
            } else {
                uint lenW = _ChildrenLen(cur);
                if (lenW == 0) return null;

                if (hints[i].Length > 0) {
                    bool advanced = false;
                    for (uint h = 0; h < hints[i].Length; ++h) {
                        int hi = hints[i][h]; if (hi < 0) continue;
                        uint uhi = uint(hi); if (uhi >= lenW) continue;
                        CControlBase@ cand = _ChildAt(cur, uhi); if (cand is null) continue;
                        @cur = cand; advanced = true; break;
                    }
                    if (!advanced) return null;
                } else {
                    CControlBase@ cand0 = _ChildAt(cur, 0);
                    if (cand0 is null) return null;
                    @cur = cand0;
                }
            }
        }
        return cur;
    }

    CControlBase@ ResolvePathHintsOnly(const string &in spec, uint overlay = 16, CControlBase@ start = null) {
        array<int> parts;
        array<bool> wc;
        array<array<int>> hints;
        
        _ParsePathEx(spec, parts, wc, hints);

        CControlBase@ cur = start;
        if (cur is null) {
            CControlFrame@ root = RootAtOverlay(overlay);
            if (root is null) return null;
            @cur = root;
        }

        for (uint i = 0; i < parts.Length; ++i) {
            if (!wc[i]) {
                int k = parts[i];
                if (k < 0) return null;
                
                uint uk = uint(k);
                uint len = _ChildrenLen(cur);
                if (uk >= len) return null;
                
                CControlBase@ ch = _ChildAt(cur, uk);
                if (ch is null) return null;

                @cur = ch; continue;
            }

            if (hints[i].Length == 0) return null;

            bool advanced = false;
            uint len2 = _ChildrenLen(cur);
            for (uint h = 0; h < hints[i].Length; ++h) {
                int hi = hints[i][h];
                if (hi < 0) continue;
                
                uint uhi = uint(hi);
                if (uhi >= len2) continue;
                
                CControlBase@ ch2 = _ChildAt(cur, uhi);
                if (ch2 is null) continue;
                @cur = ch2;
                
                advanced = true;
                break;
            }
            if (!advanced) return null;
        }
        return cur;
    }
}