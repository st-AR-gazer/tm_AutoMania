namespace UiNav {
    bool _SubtreeHasLabelStartsWith(CControlBase@ node, const string &in prefixLower) {
        if (node is null) return false;

        string t = ReadText(node);
        if (t.Length > 0) {
            string cmp = NormalizeForCompare(t).ToLower();
            if (cmp.StartsWith(prefixLower)) return true;
        }

        uint len = _ChildrenLen(node);
        for (uint i = 0; i < len; ++i) {
            if (_SubtreeHasLabelStartsWith(_ChildAt(node, i), prefixLower)) return true;
        }
        return false;
    }

    bool _ResolvePathDeepRecExGuard(CControlBase@ cur,
                                    const array<int> &in idx,
                                    const array<bool> &in wc,
                                    const array<array<int>> &in hints,
                                    uint step,
                                    const string &in guardLower,
                                    CControlBase@ &out outNode)
    {
        if (step >= idx.Length) { @outNode = cur; return true; }

        if (wc[step]) {
            uint len = _ChildrenLen(cur);

            array<uint> order;
            order.Reserve(len);
            
            array<bool> used;
            used.Resize(len);

            for (uint i = 0; i < hints[step].Length; ++i) {
                int hi = hints[step][i];
                if (hi < 0) continue;
                uint uhi = uint(hi);
                if (uhi < len && !used[uhi]) { order.InsertLast(uhi); used[uhi] = true; }
            }
            if (guardLower.Length > 0) {
                for (uint c = 0; c < len; ++c) {
                    if (used[c]) continue;
                    CControlBase@ ch = _ChildAt(cur, c);
                    if (ch !is null && _SubtreeHasLabelStartsWith(ch, guardLower)) {
                        order.InsertLast(c);
                        used[c] = true;
                    }
                }
            }
            
            for (uint c = 0; c < len; ++c) {
                if (!used[c]) order.InsertLast(c);
            }

            for (uint oi = 0; oi < order.Length; ++oi) {
                CControlBase@ ch = _ChildAt(cur, order[oi]);
                if (ch is null) continue;
                if (_ResolvePathDeepRecExGuard(ch, idx, wc, hints, step + 1, guardLower, outNode)) return true;
            }
            return false;

        } else {
            
            int k = idx[step];
            if (k < 0) return false;
            
            uint uk = uint(k);
            uint len = _ChildrenLen(cur);
            if (uk >= len) return false;

            CControlBase@ ch = _ChildAt(cur, uk);
            if (ch is null) return false;
            
            return _ResolvePathDeepRecExGuard(ch, idx, wc, hints, step + 1, guardLower, outNode);
        }
    }

    CControlBase@ ResolvePathSmart(const string &in spec, uint overlay = 16, CControlBase@ start = null) {
        CControlBase@ cur = start;
        if (cur is null) {
            CControlFrame@ root = RootAtOverlay(overlay);
            if (root is null) return null;
            @cur = root;
        }
        array<int> idx;
        array<bool> wc;
        array<array<int>> h;
        
        _ParsePathEx(spec, idx, wc, h);
        CControlBase@ outNode = null;
        if (_ResolvePathDeepRecExGuard(cur, idx, wc, h, 0, "", outNode)) return outNode;
        return null;
    }

    CControlBase@ ResolvePathSmartGuarded(const string &in spec, const string &in guardStartsWith, uint overlay = 16, CControlBase@ start = null) {
        CControlBase@ cur = start;
        if (cur is null) {
            CControlFrame@ root = RootAtOverlay(overlay);
            if (root is null) return null;
            @cur = root;
        }

        array<int> idx;
        array<bool> wc;
        array<array<int>> h;
        
        _ParsePathEx(spec, idx, wc, h);

        string guardLower = guardStartsWith.ToLower();
        CControlBase@ outNode = null;
        if (_ResolvePathDeepRecExGuard(cur, idx, wc, h, 0, guardLower, outNode)) return outNode;
        return null;
    }

    CControlBase@ ResolvePathSmartAnyRootGuarded(const string &in spec, const string &in guardStartsWith, uint overlay = 16, uint maxRoots = 24) {
        array<int> parts;
        array<bool> wc;
        array<array<int>> hints;
        
        _ParsePathEx(spec, parts, wc, hints);
        string guardLower = guardStartsWith.ToLower();

        CScene2d@ scene;
        if (!_GetScene2d(overlay, scene)) return null;
        
        uint roots = Math::Min(maxRoots, scene.Mobils.Length);

        for (uint r = 0; r < roots; ++r) {
            CControlFrame@ root = _RootFromMobil(scene, r);
            if (root is null) continue;

            CControlBase@ outNode = null;
            if (_ResolvePathDeepRecExGuard(root, parts, wc, hints, 0, guardLower, outNode)) return outNode;
        }
        return null;
    }

    CControlBase@ ResolveWithHopAnyRoot(const array<int> &in prefix, const array<int> &in hopCandidates, const array<int> &in suffix,
                                        uint overlay = 16, const string &in guardStartsWith = "", uint maxRootsToTry = 24)
    {
        CScene2d@ scene;
        if (!_GetScene2d(overlay, scene)) return null;

        string guardLower = guardStartsWith.ToLower();

        uint roots = Math::Min(maxRootsToTry, scene.Mobils.Length);
        for (uint r = 0; r < roots; ++r) {
            CControlFrame@ root = _RootFromMobil(scene, r);
            if (root is null) continue;

            CControlBase@ cur = root;
            bool ok = true;

            for (uint i = 0; i < prefix.Length; ++i) {
                int k = prefix[i];
                if (k < 0) { ok = false; break; }
                
                uint uk = uint(k);
                uint len = _ChildrenLen(cur);
                if (uk >= len) { ok = false; break; }
                
                CControlBase@ ch = _ChildAt(cur, uk);
                
                if (ch is null) { ok = false; break; }
                @cur = ch;
            }
            if (!ok) continue;

            uint lenHop = _ChildrenLen(cur);
            for (uint h = 0; h < hopCandidates.Length; ++h) {
                int hc = hopCandidates[h];
                if (hc < 0) continue;
                
                uint uhc = uint(hc);
                if (uhc >= lenHop) continue;

                CControlBase@ atHop = _ChildAt(cur, uhc);
                
                if (atHop is null) continue;

                CControlBase@ cur2 = atHop;
                
                bool ok2 = true;
                for (uint j = 0; j < suffix.Length; ++j) {
                    int k2 = suffix[j];
                    if (k2 < 0) { ok2 = false; break; }

                    uint uk2 = uint(k2);
                    uint len2 = _ChildrenLen(cur2);
                    if (uk2 >= len2) { ok2 = false; break; }
                    
                    CControlBase@ ch2 = _ChildAt(cur2, uk2);
                    if (ch2 is null) { ok2 = false; break; }
                    @cur2 = ch2;
                }
                if (!ok2) continue;

                if (guardLower.Length > 0) {
                    string t = ReadText(cur2);
                    if (t.Length == 0) continue;
                    string cmp = NormalizeForCompare(t).ToLower();
                    if (!cmp.StartsWith(guardLower)) continue;
                }
                return cur2;
            }
        }
        return null;
    }
}