namespace UiNav {
    const uint kLabelBudgetMaxVisited = 12000;

    CControlLabel@ FindLabelContains(const string &in needle, string &out foundPath, uint overlay = 16, uint maxDepth = 14, uint maxVisited = 4000) {
        foundPath = "";
        CScene2d@ scene;
        if (!_GetScene2d(overlay, scene)) return null;

        string nd = NormalizeForCompare(needle).ToLower();
        uint visited = 0;

        for (uint r = 0; r < scene.Mobils.Length; r++) {
            CControlFrame@ root = _RootFromMobil(scene, r);
            if (root is null) continue;

            array<_NodeQ@> q;
            auto st = _NodeQ();
            @st.n = root;
            st.path = "";
            st.depth = 0;
            q.InsertLast(st);
            
            uint head = 0;

            while (head < q.Length) {
                if (visited++ >= maxVisited) return null;

                auto item = q[head++];
                if (item.depth > maxDepth) continue;

                string t = ReadText(item.n);
                if (t.Length > 0) {
                    string cmp = NormalizeForCompare(t).ToLower();
                    if (cmp.Contains(nd)) { 
                        foundPath = item.path;
                        return cast<CControlLabel>(item.n); 
                    }
                }

                uint len = _ChildrenLen(item.n);
                for (uint i = 0; i < len; ++i) {
                    CControlBase@ ch = _ChildAt(item.n, i);
                    if (ch is null) continue;
                    
                    auto nx = _NodeQ();
                    @nx.n = ch;
                    nx.path = item.path.Length == 0 ? ("" + i) : (item.path + "/" + i);
                    nx.depth = item.depth + 1;
                    q.InsertLast(nx);
                }
            }
        }
        return null;
    }

    CControlLabel@ FindLabelStartsWith(const string &in prefix, string &out foundPath, uint overlay = 16, uint maxDepth = 14, uint maxVisited = 4000) {
        foundPath = "";
        CScene2d@ scene;
        if (!_GetScene2d(overlay, scene)) return null;

        string px = NormalizeForCompare(prefix).ToLower();
        uint visited = 0;

        for (uint r = 0; r < scene.Mobils.Length; r++) {
            CControlFrame@ root = _RootFromMobil(scene, r);
            if (root is null) continue;

            array<_NodeQ@> q;
            auto st = _NodeQ();
            @st.n = root;
            st.path = "";
            st.depth = 0;
            q.InsertLast(st);
            
            uint head = 0;

            while (head < q.Length) {
                if (visited++ >= maxVisited) return null;

                auto item = q[head++];
                if (item.depth > maxDepth) continue;

                string t = ReadText(item.n);
                if (t.Length > 0) {
                    string cmp = NormalizeForCompare(t).ToLower();
                    if (cmp.StartsWith(px)) {
                        foundPath = item.path;
                        return cast<CControlLabel>(item.n);
                    }
                }

                uint len = _ChildrenLen(item.n);
                for (uint i = 0; i < len; ++i) {
                    CControlBase@ ch = _ChildAt(item.n, i);
                    if (ch is null) continue;
                    
                    auto nx = _NodeQ();
                    @nx.n = ch;
                    nx.path = item.path.Length == 0 ? ("" + i) : (item.path + "/" + i);
                    
                    nx.depth = item.depth + 1;
                    q.InsertLast(nx);
                }
            }
        }
        return null;
    }

    CControlLabel@ FindLabelStartsWithBudgeted(const string &in prefix, string &out foundPath, uint overlay = 16, uint maxDepth = 14, uint nodesPerYield = 400, uint deadlineMs = 0) {
        foundPath = "";
        CScene2d@ scene;
        if (!_GetScene2d(overlay, scene)) return null;
        
        string px = NormalizeForCompare(prefix).ToLower();

        uint visited = 0;
        uint ny = nodesPerYield > 0 ? nodesPerYield : 80;

        for (uint r = 0; r < scene.Mobils.Length; r++) {
            CControlFrame@ root = _RootFromMobil(scene, r);
            if (root is null) continue;

            array<_NodeQ@> q;
            auto st = _NodeQ();
            @st.n = root;
            st.path = "";
            st.depth = 0;
            q.InsertLast(st);
            
            uint head = 0;

            while (head < q.Length) {
                if (deadlineMs != 0 && Time::Now >= deadlineMs) { foundPath = ""; return null; }

                auto item = q[head++];
                if (item.depth > maxDepth) continue;

                string t = ReadText(item.n);
                if (t.Length > 0) {
                    string cmp = NormalizeForCompare(t).ToLower();
                    if (cmp.StartsWith(px)) {
                        foundPath = item.path;
                        return cast<CControlLabel>(item.n);
                    }
                }

                uint len = _ChildrenLen(item.n);
                for (uint i = 0; i < len; ++i) {
                    CControlBase@ ch = _ChildAt(item.n, i);
                    if (ch is null) continue;
                    
                    auto nx = _NodeQ();
                    @nx.n = ch;
                    nx.path = item.path.Length == 0 ? ("" + i) : (item.path + "/" + i);
                    
                    nx.depth = item.depth + 1;
                    q.InsertLast(nx);
                }

                visited++;
                if (kLabelBudgetMaxVisited != 0 && visited >= kLabelBudgetMaxVisited) {
                    foundPath = "";
                    return null;
                }

                if ((visited % ny) == 0) {
                    yield(0);
                    if (deadlineMs != 0 && Time::Now >= deadlineMs) { foundPath = ""; return null; }
                }
            }
        }
        return null;
    }

    CControlLabel@ FindLabelContainsBudgeted(const string &in needle, string &out foundPath, uint overlay = 16, uint maxDepth = 14, uint nodesPerYield = 400, uint deadlineMs = 0) {
        foundPath = "";
        CScene2d@ scene;
        if (!_GetScene2d(overlay, scene)) return null;
        
        string nd = NormalizeForCompare(needle).ToLower();

        uint visited = 0;
        uint ny = nodesPerYield > 0 ? nodesPerYield : 80;

        for (uint r = 0; r < scene.Mobils.Length; r++) {
            CControlFrame@ root = _RootFromMobil(scene, r);
            if (root is null) continue;

            array<_NodeQ@> q;
            auto st = _NodeQ();
            @st.n = root;
            st.path = "";
            st.depth = 0;
            q.InsertLast(st);
            
            uint head = 0;

            while (head < q.Length) {
                if (deadlineMs != 0 && Time::Now >= deadlineMs) { foundPath = ""; return null; }

                auto item = q[head++];
                if (item.depth > maxDepth) continue;

                string t = ReadText(item.n);
                if (t.Length > 0) {
                    string cmp = NormalizeForCompare(t).ToLower();
                    if (cmp.Contains(nd)) {
                        foundPath = item.path;
                        return cast<CControlLabel>(item.n);
                    }
                }

                uint len = _ChildrenLen(item.n);
                for (uint i = 0; i < len; ++i) {
                    CControlBase@ ch = _ChildAt(item.n, i);
                    if (ch is null) continue;
                    
                    auto nx = _NodeQ();
                    @nx.n = ch;
                    nx.path = item.path.Length == 0 ? ("" + i) : (item.path + "/" + i);
                    
                    nx.depth = item.depth + 1;
                    q.InsertLast(nx);
                }

                visited++;
                if (kLabelBudgetMaxVisited != 0 && visited >= kLabelBudgetMaxVisited) {
                    foundPath = "";
                    return null;
                }

                if ((visited % ny) == 0) {
                    yield(0);
                    if (deadlineMs != 0 && Time::Now >= deadlineMs) { foundPath = ""; return null; }
                }
            }
        }
        return null;
    }

    bool PathHasLabelContains(const string &in basePath, const string &in needle, uint overlay = 16, int maxNodes = 1500, uint maxDepth = 10) {
        CControlBase@ base = ResolvePath(basePath, overlay);
        if (base is null) return false;

        array<_NodeQ@> q;
        auto st = _NodeQ();
        @st.n = base;
        st.path = "";
        st.depth = 0;
        q.InsertLast(st);
        
        int visited = 0;
        string nd = NormalizeForCompare(needle).ToLower();

        while (q.Length > 0 && visited < maxNodes) {
            auto item = q[0]; q.RemoveAt(0);
            visited++;

            if (item.depth <= maxDepth) {
                string t = ReadText(item.n);
                if (t.Length > 0) {
                    string cmp = NormalizeForCompare(t).ToLower();
                    if (cmp.Contains(nd)) return true;
                }

                uint len = _ChildrenLen(item.n);
                for (uint i = 0; i < len; ++i) {
                    CControlBase@ ch = _ChildAt(item.n, i);
                    if (ch is null) continue;
                    
                    auto nx = _NodeQ();
                    @nx.n = ch;
                    nx.path = "";
                    nx.depth = item.depth + 1;
                    
                    q.InsertLast(nx);
                }
            }
        }
        return false;
    }
}