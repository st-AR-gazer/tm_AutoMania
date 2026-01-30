namespace UiNav {

    CControlBase@ ResolvePathExactAnyRoot(const string &in spec, uint overlay = 16) {
        if (SpecHasWildcard(spec)) return null;

        array<int> idx;
        array<bool> wc;
        array<array<int>> h;
        
        _ParsePathEx(spec, idx, wc, h);

        CScene2d@ scene;
        if (!_GetScene2d(overlay, scene)) return null;
        
        for (uint r = 0; r < scene.Mobils.Length; ++r) {
            CControlFrame@ root = _RootFromMobil(scene, r);
            
            if (root is null) continue;
            CControlBase@ cur = root;
            bool ok = true;
            
            for (uint s = 0; s < idx.Length; ++s) {
                int k = idx[s];
                if (k < 0) { ok = false; break; }
                
                uint uk = uint(k);
                uint len = _ChildrenLen(cur);
                
                if (uk >= len) { ok = false; break; }
                
                CControlBase@ ch = _ChildAt(cur, uk);
                
                if (ch is null) { ok = false; break; }
                
                @cur = ch;
            }
            if (ok) return cur;
        }
        return null;
    }

    CControlBase@ ResolvePathAnyRoot(const string &in spec, uint overlay = 16, uint maxRoots = 24) {
        array<int> parts;
        array<bool> wc;
        array<array<int>> hints;
        
        _ParsePathEx(spec, parts, wc, hints);

        CScene2d@ scene;
        
        if (!_GetScene2d(overlay, scene)) return null;
        uint roots = Math::Min(maxRoots, scene.Mobils.Length);

        for (uint r = 0; r < roots; ++r) {
            CControlFrame@ root = _RootFromMobil(scene, r);
            if (root is null) continue;

            CControlBase@ cur = cast<CControlBase@>(root);
            bool ok = true;

            for (uint i = 0; i < parts.Length && ok; ++i) {
                if (!wc[i]) {
                    int k = parts[i]; if (k < 0) { ok = false; break; }
                    uint uk = uint(k), len = _ChildrenLen(cur);
                    if (uk >= len) { ok = false; break; }
                    CControlBase@ ch = _ChildAt(cur, uk);
                    if (ch is null) { ok = false; break; }
                    @cur = ch;
                } else {
                    uint lenW = _ChildrenLen(cur);
                    if (lenW == 0) { ok = false; break; }

                    if (hints[i].Length > 0) {
                        bool advanced = false;
                        for (uint h = 0; h < hints[i].Length; ++h) {
                            int hi = hints[i][h];
                            if (hi < 0) continue;
                            uint uhi = uint(hi);
                            if (uhi >= lenW) continue;
                            
                            CControlBase@ cand = _ChildAt(cur, uhi);
                            
                            if (cand is null) continue;
                            
                            @cur = cand;
                            advanced = true;
                            
                            break;
                        }
                        if (!advanced) { ok = false; break; }

                    } else {
                        CControlBase@ cand0 = _ChildAt(cur, 0);
                        if (cand0 is null) { ok = false; break; }
                        @cur = cand0;
                    }
                }
            }

            if (ok) return cur;
        }
        return null;
    }

    bool _ResolvePathHintsOnlyRec(CControlBase@ cur,
                                  const array<int> &in idx,
                                  const array<bool> &in wc,
                                  const array<array<int>> &in hints,
                                  uint step,
                                  CControlBase@ &out outNode)
    {
        if (step >= idx.Length) { @outNode = cur; return true; }

        if (!wc[step]) {
            int k = idx[step];
            if (k < 0) return false;
            uint uk = uint(k);
            uint len = _ChildrenLen(cur);
            if (uk >= len) return false;
            CControlBase@ ch = _ChildAt(cur, uk);
            if (ch is null) return false;
            return _ResolvePathHintsOnlyRec(ch, idx, wc, hints, step + 1, outNode);
        }

        if (hints[step].Length == 0) return false;

        for (uint i = 0; i < hints[step].Length; ++i) {
            int hi = hints[step][i];
            if (hi < 0) continue;
            uint uhi = uint(hi);
            uint len2 = _ChildrenLen(cur);
            if (uhi >= len2) continue;
            CControlBase@ ch2 = _ChildAt(cur, uhi);
            if (ch2 is null) continue;
            if (_ResolvePathHintsOnlyRec(ch2, idx, wc, hints, step + 1, outNode)) return true;
        }
        return false;
    }

    CControlBase@ ResolvePathHintsOnlyAnyRoot(const string &in spec, uint overlay = 16) {
        if (!SpecHasWildcard(spec)) return null;

        array<int> idx;
        array<bool> wc;
        array<array<int>> hints;
        
        _ParsePathEx(spec, idx, wc, hints);

        CScene2d@ scene; if (!_GetScene2d(overlay, scene)) return null;
        for (uint r = 0; r < scene.Mobils.Length; ++r) {
            CControlFrame@ root = _RootFromMobil(scene, r);
            if (root is null) continue;

            CControlBase@ outNode = null;
            if (_ResolvePathHintsOnlyRec(root, idx, wc, hints, 0, outNode)) return outNode;
        }
        return null;
    }
}