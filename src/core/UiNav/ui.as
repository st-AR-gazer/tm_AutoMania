namespace UiNav {
namespace DevUI {

#if SIG_DEVELOPER
    [Setting category="Dev"] bool S_ShowUiNavDev = true;
#else
    bool S_ShowUiNavDev = false;
#endif

    uint  gOverlay          = 3;
    uint  gMobil            = 0;

    float gColWidthFull     = 850.0f;
    float gColHeightFull    = 450.0f;
    float gVisibleColsFull  = 2.1f;
    const float kGapFull    = 12.0f;

    bool  gCompactView      = false;
    float gColWidthCompact  = 150.0f;
    float gColHeightCompact = 380.0f;
    float gVisibleColsComp  = 8.2f;
    const float kGapComp    = 6.0f;

    bool  gWheelNeedsShift  = false;

    int   gScrollToCol      = -1;

    uint  gBoundOverlay     = uint(-1);
    uint  gBoundMobil       = uint(-1);

    class Row {
        uint idx;
        string type;
        string text;
    }

    class Col {
        string        parentPath;
        CControlBase@ parentNode;
        array<Row@>   rows;
        int           selected = -1;
    }

    array<Col@> gCols;
    array<int>  gPath;
    string      gStatus = "";
    string      gMsg    = "";

    float ColW()    { return gCompactView ? gColWidthCompact  : gColWidthFull; }
    float GapW()    { return gCompactView ? kGapComp          : kGapFull; }
    float VisCols() { return gCompactView ? gVisibleColsComp  : gVisibleColsFull; }
    float ColH()    { return gCompactView ? gColHeightCompact : gColHeightFull; }

    void OpenInNodeExplorer(CControlBase@ n) {
        if (n is null) return;

#if SIG_DEVELOPER
        ExploreNod(n);
#else
        UI::ShowNotification("UINav", "Node Explorer can only be opened in the SIG_DEVELOPER mode.", 3000);
#endif
    }

    string GetMwIdName(CControlBase@ n) {
        if (n is null) return "";
        MwId id = n.Id;
        return id.GetName();
    }

    bool GetEffectiveVisible(CControlBase@ n) { return n !is null && n.IsVisible && !n.IsHiddenExternal; }

    void ApplyVisibilityStrict(CControlBase@ n, bool show) {
        if (n is null) return;
        if (show) {
            n.IsVisible = true;
        } else {
            n.IsHiddenExternal = true;
        }
    }

    bool GetSceneAndRoot(uint overlay, uint mobil, CScene2d@ &out scene, CControlFrame@ &out root) {
        @scene = null; @root = null;
        
        if (!UiNav::_GetScene2d(overlay, scene)) { gStatus = "Overlay not available"; return false; }
        if (mobil >= scene.Mobils.Length) { gStatus = "Mobil root out of range"; return false; }

        @root = UiNav::_RootFromMobil(scene, mobil);
        if (root is null) { gStatus = "Root frame null"; return false; }

        return true;
    }

    CControlBase@ ResolveChildLive(const string &in parentPath, uint childIdx) {
        CScene2d@ scene;
        CControlFrame@ root;
        
        if (!GetSceneAndRoot(gOverlay, gMobil, scene, root)) return null;
        string childPath = parentPath.Length == 0 ? ("" + childIdx) : (parentPath + "/" + childIdx);
        
        return UiNav::ResolvePath(childPath, gOverlay, root);
    }

    void FillRowsForNode(CControlBase@ node, array<Row@> &out rows) {
        rows.RemoveRange(0, rows.Length);
        if (node is null) return;
        uint len = UiNav::_ChildrenLen(node);
        rows.Reserve(len);
        for (uint i = 0; i < len; ++i) {
            CControlBase@ ch = UiNav::_ChildAt(node, i);
            if (ch is null) continue;
            Row@ r = Row();
            r.idx  = i;
            r.type = UiNav::NodeTypeName(ch);
            string t = UiNav::ReadText(ch);
            if (t.Length > 160) t = t.SubStr(0, 160) + "...";
            r.text = UiNav::CleanUiFormatting(t);
            rows.InsertLast(r);
        }
    }

    void ClearAll()  { gCols.RemoveRange(0, gCols.Length); gMsg = ""; }
    void ClearPath() { gPath.RemoveRange(0, gPath.Length); }

    void RebuildColumns(bool resetPath) {
        if (resetPath) ClearPath();
        ClearAll();

        CScene2d@ scene; CControlFrame@ root;
        if (!GetSceneAndRoot(gOverlay, gMobil, scene, root)) return;

        Col@ c = Col();
        c.parentPath = "";
        @c.parentNode = root;
        FillRowsForNode(root, c.rows);
        gCols.InsertLast(c);

        gBoundOverlay = gOverlay;
        gBoundMobil   = gMobil;

        gStatus = "Ready";
        SyncSelectionsFromPath();
    }

    void RefreshColumnsBinding() {
        if (gCols.Length == 0) return;
        
        CScene2d@ scene;
        CControlFrame@ root;
        
        if (!GetSceneAndRoot(gOverlay, gMobil, scene, root)) return;

        for (uint i = 0; i < gCols.Length; ++i) {
            Col@ col = gCols[i];
            if (col is null) continue;

            CControlBase@ node = col.parentPath.Length == 0 ? cast<CControlBase@>(root) : UiNav::ResolvePath(col.parentPath, gOverlay, root);

            @col.parentNode = node;

            if (node !is null) {
                uint curCount = UiNav::_ChildrenLen(node);
                if (curCount != col.rows.Length) {
                    FillRowsForNode(node, col.rows);
                    if (col.selected >= int(curCount)) col.selected = -1;
                }
            }
        }
    }

    void EnsureColumnsAlive() {
        if (gCols.Length == 0 || gBoundOverlay == uint(-1) || gBoundMobil == uint(-1)) {
            RebuildColumns(true);
            return;
        }
        if (gBoundOverlay != gOverlay || gBoundMobil != gMobil) {
            RebuildColumns(true);
            return;
        }
        RefreshColumnsBinding();
    }

    void SyncSelectionsFromPath() {
        for (uint i = 0; i < gCols.Length; ++i) {
            Col@ col = gCols[i];
            if (col is null) continue;
            if (i < gPath.Length) col.selected = gPath[i];
            else col.selected = -1;
        }
    }

    void ParsePathString(const string &in s, array<int> &out outIdx) {
        outIdx.RemoveRange(0, outIdx.Length);
        if (s.Length == 0) return;
        auto parts = s.Split("/");
        for (uint i = 0; i < parts.Length; ++i) {
            string p = parts[i].Trim();
            if (p.Length == 0) continue;
            outIdx.InsertLast(Text::ParseInt(p));
        }
    }

    void PickPath(uint colIx, uint rowIdx) {
        if (colIx >= gCols.Length) return;
        Col@ col = gCols[colIx];
        if (col is null) return;

        array<int> np;
        ParsePathString(col.parentPath, np);
        np.InsertLast(int(rowIdx));

        ClearPath();
        for (uint i = 0; i < np.Length; ++i) { gPath.InsertLast(np[i]); }

        if (colIx + 1 < gCols.Length) gCols.RemoveRange(colIx + 1, gCols.Length - (colIx + 1));

        SyncSelectionsFromPath();
    }

    void _SyncPathOnEnter(uint colIx, uint childIdx) {
        if (colIx >= gCols.Length) return;
        Col@ col = gCols[colIx];
        if (col is null) return;

        array<int> np;
        ParsePathString(col.parentPath, np);
        np.InsertLast(int(childIdx));

        ClearPath();
        for (uint i = 0; i < np.Length; ++i) gPath.InsertLast(np[i]);
        SyncSelectionsFromPath();
    }

    void OpenChild(uint colIx, uint childIdx) {
        if (colIx >= gCols.Length) return;
        Col@ col = gCols[colIx];
        if (col is null || col.parentNode is null) return;

        CControlBase@ child = UiNav::_ChildAt(col.parentNode, childIdx);
        if (child is null) @child = ResolveChildLive(col.parentPath, childIdx);
        if (child is null) { gMsg = "Child is null"; return; }

        string nextPath = col.parentPath.Length == 0 ? ("" + childIdx) : (col.parentPath + "/" + childIdx);

        if (colIx + 1 < gCols.Length) gCols.RemoveRange(colIx + 1, gCols.Length - (colIx + 1));

        Col@ nxt = Col();
        nxt.parentPath = nextPath;
        @nxt.parentNode = child;
        FillRowsForNode(child, nxt.rows);
        gCols.InsertLast(nxt);

        _SyncPathOnEnter(colIx, childIdx);

        gMsg = "Entered child " + childIdx + " -> new column";
        gScrollToCol = int(colIx) + 1;
    }

    string PathToString() {
        if (gPath.Length == 0) return "";
        string s = "" + gPath[0];
        for (uint i = 1; i < gPath.Length; ++i) {
            s += "/" + gPath[i];
        }
        return s;
    }

    void DrawColumn_Expanded(uint colIx, Col@ col) {
        if (col is null) return;

        float colW = ColW();
        float colH = ColH();
        UI::BeginChild("##col-" + colIx, vec2(colW, colH), true);

        string title = col.parentPath.Length == 0 ? "(root)" : col.parentPath;
        UI::TextDisabled("Parent: " + title);
        UI::SameLine();
        if (UI::Button("Back to here")) {
            if (colIx + 1 < gCols.Length) gCols.RemoveRange(colIx + 1, gCols.Length - (colIx + 1));
            if (colIx < gPath.Length)     gPath.RemoveRange(colIx, gPath.Length - colIx);
            SyncSelectionsFromPath();
        }

        UI::Separator();

        UI::PushStyleColor(UI::Col::TableRowBg,    vec4(0.10f, 0.12f, 0.16f, 0.25f));
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.10f, 0.12f, 0.16f, 0.38f));

        if (UI::BeginTable("##table-" + colIx, 7,
            UI::TableFlags::RowBg | UI::TableFlags::BordersInnerH | UI::TableFlags::BordersOuter | UI::TableFlags::SizingStretchSame))
        {
            UI::TableSetupColumn("Pick",        UI::TableColumnFlags::WidthFixed, 28.0f);
            UI::TableSetupColumn("Idx",         UI::TableColumnFlags::WidthFixed, 32.0f);
            UI::TableSetupColumn("Type",        UI::TableColumnFlags::WidthFixed, 100.0f);
            UI::TableSetupColumn("MwId (Name)", UI::TableColumnFlags::WidthFixed, 180.0f);
            UI::TableSetupColumn("Label",       UI::TableColumnFlags::WidthStretch, 1.0f);
            UI::TableSetupColumn("Visible",     UI::TableColumnFlags::WidthFixed, 70.0f);
            UI::TableSetupColumn("Enter/Open",  UI::TableColumnFlags::WidthFixed, 155.0f);
            UI::TableHeadersRow();

            UI::ListClipper clip(col.rows.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; ++i) {
                    Row@ r = col.rows[uint(i)];
                    if (r is null) continue;

                    bool isSel = (col.selected == int(r.idx));
                    UI::TableNextRow();

                    if (isSel) {
                        UI::TableSetBgColor(UI::TableBgTarget::RowBg0, vec4(0.80f, 0.80f, 0.20f, 0.05f));
                    }

                    UI::PushID("row-" + colIx + "-" + r.idx);

                    CControlBase@ ch = ResolveChildLive(col.parentPath, r.idx);

                    UI::TableNextColumn();
                    bool wantPick = isSel;
                    wantPick = UI::Checkbox("##pick", wantPick);
                    if (wantPick != isSel) {
                        if (wantPick) {
                            PickPath(colIx, r.idx);
                            isSel = true;
                        } else {
                            if (colIx < gPath.Length) gPath.RemoveRange(colIx, gPath.Length - colIx);
                            for (uint k = colIx; k < gCols.Length; ++k) {
                                if (gCols[k] !is null) gCols[k].selected = -1;
                            }
                        }
                    }

                    UI::TableNextColumn(); UI::Text("" + r.idx);
                    UI::TableNextColumn(); UI::Text(r.type);
                    UI::TableNextColumn();
                    if (ch is null) {
                        UI::TextDisabled("-");
                    } else {
                        string idn = GetMwIdName(ch);
                        if (idn.Length == 0) idn = "\\$bbb(n/a)";
                        UI::Text(idn);
                    }
                    UI::TableNextColumn();
                    string label = r.text.Length > 0 ? r.text : "\\$bbb(no label)";
                    if (UI::Selectable(label, isSel)) {
                        PickPath(colIx, r.idx);
                        isSel = true;
                    }
                    UI::TableNextColumn();
                    if (ch is null) {
                        UI::TextDisabled("-");
                    } else {
                        bool effVis = GetEffectiveVisible(ch);
                        bool wantOn = effVis;
                        wantOn = UI::Checkbox("##vis", wantOn);
                        if (wantOn != effVis) {
                            ApplyVisibilityStrict(ch, wantOn);
                            @ch = ResolveChildLive(col.parentPath, r.idx);
                            effVis = GetEffectiveVisible(ch);
                            if (effVis != wantOn && ch !is null) {
                                if (wantOn) {
                                    ch.IsHiddenExternal = false;
                                    ch.IsVisible = true;
                                } else {
                                    ch.IsHiddenExternal = true;
                                }
                            }
                        }
                        UI::SameLine();
                        UI::Text(effVis ? "\\$0f0On" : "\\$f55Off");
                    }

                    UI::TableNextColumn();
                    if (UI::Button("Enter", vec2(48.0f, 0.0f))) { OpenChild(colIx, r.idx); }
                    UI::SameLine();
                    if (UI::Button("Open", vec2(48.0f, 0.0f))) { OpenInNodeExplorer(ch); }

                    UI::PopID();
                }
            }
            UI::EndTable();
        }

        UI::PopStyleColor(2);
        UI::EndChild();
    }

    void DrawColumn_Compact(uint colIx, Col@ col) {
        if (col is null) return;

        float colW = ColW();
        float colH = ColH();
        UI::BeginChild("##colc-" + colIx, vec2(colW, colH), true);

        UI::PushStyleColor(UI::Col::TableRowBg,    vec4(0.10f, 0.12f, 0.16f, 0.25f));
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.10f, 0.12f, 0.16f, 0.38f));

        if (UI::BeginTable("##tablec-" + colIx, 3,
            UI::TableFlags::RowBg | UI::TableFlags::BordersInnerH | UI::TableFlags::BordersOuter | UI::TableFlags::SizingFixedFit))
        {
            UI::TableSetupColumn("Idx",   UI::TableColumnFlags::WidthFixed, 20.0f);
            UI::TableSetupColumn("Vis",   UI::TableColumnFlags::WidthFixed, 23.0f);
            UI::TableSetupColumn("Enter", UI::TableColumnFlags::WidthFixed, 72.0f);
            UI::TableHeadersRow();

            UI::ListClipper clip(col.rows.Length);

            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; ++i) {
                    Row@ r = col.rows[uint(i)];
                    if (r is null) continue;

                    bool isSel = (col.selected == int(r.idx));
                    UI::TableNextRow();

                    if (isSel) { UI::TableSetBgColor(UI::TableBgTarget::RowBg0, vec4(0.80f, 0.80f, 0.20f, 0.05f)); }

                    UI::PushID("crow-" + colIx + "-" + r.idx);

                    UI::TableNextColumn(); UI::Text("" + r.idx);
                    UI::TableNextColumn();
                    {
                        CControlBase@ ch = ResolveChildLive(col.parentPath, r.idx);
                        if (ch is null) {
                            UI::TextDisabled("-");
                        } else {
                            bool effVis = GetEffectiveVisible(ch);
                            bool wantOn = effVis;
                            wantOn = UI::Checkbox("##cvis", wantOn);
                            if (wantOn != effVis) {
                                ApplyVisibilityStrict(ch, wantOn);
                                @ch = ResolveChildLive(col.parentPath, r.idx);
                                effVis = GetEffectiveVisible(ch);
                                if (effVis != wantOn && ch !is null) {
                                    if (wantOn) { ch.IsHiddenExternal = false; ch.IsVisible = true; }
                                    else        { ch.IsHiddenExternal = true; }
                                }
                            }
                        }
                    }
                    UI::TableNextColumn();
                    if (UI::Button("Enter", vec2(68.0f, 0.0f))) {
                        PickPath(colIx, r.idx);
                        OpenChild(colIx, r.idx);
                    }

                    UI::PopID();
                }
            }
            UI::EndTable();
        }

        UI::PopStyleColor(2);
        UI::EndChild();
    }

    void DrawColumn(uint colIx, Col@ col) {
        if (gCompactView) {
            DrawColumn_Compact(colIx, col);
        } else {
            DrawColumn_Expanded(colIx, col);
        }
    }

    void DrawCurrentPathActions() {
        string curPath = PathToString();
        CScene2d@ scene;
        CControlFrame@ root;
        
        bool haveRoot = GetSceneAndRoot(gOverlay, gMobil, scene, root);

        UI::TextDisabled("Current path (relative to mobil " + gMobil + "):");
        UI::SameLine();
        UI::Text(curPath.Length == 0 ? "\\$bbb(none)" : curPath);

        UI::SameLine();
        if (curPath.Length > 0 && UI::Button("Copy")) IO::SetClipboard(curPath);

        if (curPath.Length > 0 && !gCompactView) {
            UI::SameLine();
            if (UI::Button("Test")) {
                CControlBase@ n = haveRoot ? UiNav::ResolvePath(curPath, gOverlay, root) : null;
                UI::ShowNotification("UINav", n is null ? "ResolvePath: not found" : ("ResolvePath: OK (" + UiNav::NodeTypeName(n) + ")"), 2500);
            }

            UI::SameLine();
            if (UI::Button("Read")) {
                CControlBase@ n = haveRoot ? UiNav::ResolvePath(curPath, gOverlay, root) : null;
                string t = n is null ? "" : UiNav::ReadText(n);
                if (t.Length == 0) t = "(empty or null)";
                UI::ShowNotification("UINav Read", t, 3800);
            }

            UI::SameLine();
            if (UI::Button("Click")) {
                CControlBase@ n = haveRoot ? UiNav::ResolvePath(curPath, gOverlay, root) : null;
                bool ok = false;
                if (n !is null) {
                    CControlQuad@ q = cast<CControlQuad>(n);
                    if (q !is null) { q.OnAction(); ok = true; }
                    
                    CControlButton@ b = cast<CControlButton>(n);
                    if (b !is null) { b.OnAction(); ok = true; }
                    
                    CGameControlCardGeneric@ c = cast<CGameControlCardGeneric>(n);
                    if (c !is null) { c.OnAction(); ok = true; }
                    
                    if (!ok) {
                        uint len = UiNav::_ChildrenLen(n);
                        for (uint i = 0; i < len && !ok; ++i) {
                            CControlBase@ ch = UiNav::_ChildAt(n, i);
                            if (ch is null) continue;
                            
                            CControlQuad@ q0 = cast<CControlQuad>(ch);
                            if (q0 !is null) { q0.OnAction(); ok = true; break; }
                            
                            CControlButton@ b0 = cast<CControlButton>(ch);
                            if (b0 !is null) { b0.OnAction(); ok = true; break; }
                            
                            CGameControlCardGeneric@ c0 = cast<CGameControlCardGeneric>(ch);
                            if (c0 !is null) { c0.OnAction(); ok = true; break; }
                        }
                    }
                }
                UI::ShowNotification("UINav Click", ok ? "Clicked" : "No clickable control", 2500);
            }
        }
    }

    void DrawCompactTopBar() {
        string curPath = PathToString();

        UI::TextDisabled("Overlay: " + gOverlay + " | Mobil: " + gMobil);
        UI::SameLine();
        string shown = curPath.Length == 0 ? "\\$bbb(none)" : curPath;
        UI::SameLine();
        UI::Text(shown);

        UI::SameLine();
        if (UI::Button("Exit Compact")) {
            gCompactView = false;
        }
        if (curPath.Length > 0) {
            UI::SameLine();
            if (UI::Button("Copy")) IO::SetClipboard(curPath);
        }

    }

    void Render() {
        if (!S_ShowUiNavDev) return;

        if (!UI::Begin("UI Navigator (Finder)###UINavDevFinder", S_ShowUiNavDev, UI::WindowFlags::AlwaysAutoResize)) { UI::End(); return; }

        if (gCompactView) {
            DrawCompactTopBar();
            UI::SeparatorText("Path");
            EnsureColumnsAlive();
            SyncSelectionsFromPath();

            float colW  = ColW();
            float gapW  = GapW();
            float vis   = VisCols();
            float gaps  = Math::Max(0.0f, Math::Ceil(vis) - 1.0f);
            float viewW = colW * vis + gapW * gaps;
            float viewH = ColH() + 40.0f;

            float contentW = (gCols.Length > 0) ? (colW * float(gCols.Length) + gapW * float(gCols.Length - 1)) : 0.0f;

            UI::BeginChild("##columns-scroll-compact", vec2(viewW, viewH), true, UI::WindowFlags::HorizontalScrollbar); {
                for (uint i = 0; i < gCols.Length; ++i) {
                    if (i > 0) UI::SameLine(0, gapW);
                    DrawColumn_Compact(i, gCols[i]);
                }

                float wheel = UI::GetMouseWheelDeltaHor();
                if (wheel != 0.0f && contentW > viewW) {
                    bool allow = true;
                    if (gWheelNeedsShift) { allow = UI::IsKeyDown(UI::Key::LeftShift) || UI::IsKeyDown(UI::Key::RightShift); }
                    if (allow) {
                        float step = (colW + gapW);
                        float x    = UI::GetScrollX();
                        float maxX = Math::Max(0.0f, contentW - viewW);
                        x -= wheel * step;
                        if (x < 0.0f) x = 0.0f;
                        if (x > maxX) x = maxX;
                        UI::SetScrollX(x);
                    }
                }

                if (gScrollToCol >= 0 && gScrollToCol < int(gCols.Length)) {
                    float colLeft   = float(gScrollToCol) * (colW + gapW);
                    float colRight  = colLeft + colW;
                    float viewLeft  = UI::GetScrollX();
                    float viewRight = viewLeft + viewW;

                    float target = viewLeft;
                    if (colRight > viewRight) {
                        target = colRight - viewW;
                    } else if (colLeft < viewLeft) {
                        target = colLeft;
                    }

                    float maxX = Math::Max(0.0f, contentW - viewW);
                    if (target < 0.0f) target = 0.0f;
                    if (target > maxX) target = maxX;

                    UI::SetScrollX(target);
                    gScrollToCol = -1;
                }
            }
            UI::EndChild();

            if (gMsg.Length > 0) { UI::Separator(); UI::TextDisabled(gMsg); }

            UI::End();
            return;
        }


        UI::TextDisabled("Overlay / Mobil"); UI::Separator();

        UI::PushItemWidth(90);
        {
            int ovOld = int(gOverlay), ovNew = UI::InputInt("Overlay", ovOld);
            if (ovNew != ovOld) { gOverlay = uint(Math::Max(0, ovNew)); RebuildColumns(true); }
        }
        UI::PopItemWidth();

        UI::SameLine();
        UI::PushItemWidth(90);
        {
            CScene2d@ scene; uint maxMobil = 0;
            if (UiNav::_GetScene2d(gOverlay, scene)) maxMobil = scene.Mobils.Length > 0 ? (scene.Mobils.Length - 1) : 0;
            int mbOld = int(gMobil), mbNew = UI::InputInt("Mobil", mbOld);
            if (mbNew != mbOld) {
                if (mbNew < 0) mbNew = 0;
                if (scene !is null) mbNew = int(Math::Min(uint(mbNew), maxMobil));
                gMobil = uint(mbNew);
                RebuildColumns(true);
            }
        }
        UI::PopItemWidth();

        UI::SameLine();
        if (UI::Button("Reset")) RebuildColumns(true);

        UI::Dummy(vec2(0, 6));
        UI::TextDisabled("Layout");
        UI::Separator();

        gCompactView = UI::Checkbox("Compact view (Idx | Visible | Enter)", gCompactView);

        UI::PushItemWidth(160);
        {
            float f = gColWidthFull, n = UI::InputFloat("Full col width", f);
            if (n != f) { if (n < 260.0f) n = 260.0f; if (n > 1600.0f) n = 1600.0f; gColWidthFull = n; }
        }
        UI::PopItemWidth();

        UI::SameLine();
        UI::PushItemWidth(160);
        {
            float f = gVisibleColsFull, n = UI::InputFloat("Full visible cols", f);
            if (n != f) { if (n < 1.0f) n = 1.0f; if (n > 12.0f) n = 12.0f; gVisibleColsFull = n; }
        }
        UI::PopItemWidth();

        UI::SameLine();
        UI::PushItemWidth(160);
        {
            float f = gColHeightFull, n = UI::InputFloat("Full col height", f);
            if (n != f) { if (n < 160.0f) n = 160.0f; if (n > 1600.0f) n = 1600.0f; gColHeightFull = n; }
        }
        UI::PopItemWidth();

        UI::Dummy(vec2(0, 4));
        UI::TextDisabled("Compact sizes");
        UI::PushItemWidth(160);
        {
            float f = gColWidthCompact, n = UI::InputFloat("Compact col width", f);
            if (n != f) { if (n < 120.0f) n = 120.0f; if (n > 1200.0f) n = 1200.0f; gColWidthCompact = n; }
        }
        UI::PopItemWidth();

        UI::SameLine(); UI::PushItemWidth(160);
        {
            float f = gVisibleColsComp, n = UI::InputFloat("Compact visible cols", f);
            if (n != f) { if (n < 2.0f) n = 2.0f; if (n > 24.0f) n = 24.0f; gVisibleColsComp = n; }
        }
        UI::PopItemWidth();

        UI::SameLine(); UI::PushItemWidth(160);
        {
            float f = gColHeightCompact, n = UI::InputFloat("Compact col height", f);
            if (n != f) { if (n < 120.0f) n = 120.0f; if (n > 1600.0f) n = 1600.0f; gColHeightCompact = n; }
        }
        UI::PopItemWidth();

        UI::Dummy(vec2(0, 6));
        DrawCurrentPathActions();

        UI::Dummy(vec2(0, 6));
        UI::TextDisabled("Columns"); UI::Separator();

        EnsureColumnsAlive();
        SyncSelectionsFromPath();

        float colW   = ColW();
        float gapW   = GapW();
        float vis    = VisCols();
        float gaps   = Math::Max(0.0f, Math::Ceil(vis) - 1.0f);
        float viewW  = colW * vis + gapW * gaps;
        float viewH  = ColH() + 40.0f;

        float contentW = (gCols.Length > 0) ? (colW * float(gCols.Length) + gapW * float(gCols.Length - 1)) : 0.0f;

        UI::BeginChild("##columns-scroll", vec2(viewW, viewH), true, UI::WindowFlags::HorizontalScrollbar); {
            for (uint i = 0; i < gCols.Length; ++i) {
                if (i > 0) UI::SameLine(0, gapW);
                DrawColumn(i, gCols[i]);
            }

            float wheel = UI::GetMouseWheelDeltaHor();
            if (wheel != 0.0f && contentW > viewW) {
                bool allow = true;
                if (gWheelNeedsShift) { allow = UI::IsKeyDown(UI::Key::LeftShift) || UI::IsKeyDown(UI::Key::RightShift); }
                if (allow) {
                    float step = (colW + gapW);
                    float x    = UI::GetScrollX();
                    float maxX = Math::Max(0.0f, contentW - viewW);
                    x -= wheel * step;
                    if (x < 0.0f) x = 0.0f;
                    if (x > maxX) x = maxX;
                    UI::SetScrollX(x);
                }
            }

            if (gScrollToCol >= 0 && gScrollToCol < int(gCols.Length)) {
                float colLeft   = float(gScrollToCol) * (colW + gapW);
                float colRight  = colLeft + colW;
                float viewLeft  = UI::GetScrollX();
                float viewRight = viewLeft + viewW;

                float target = viewLeft;
                if (colRight > viewRight) {
                    target = colRight - viewW;
                } else if (colLeft < viewLeft) {
                    target = colLeft;
                }

                float maxX = Math::Max(0.0f, contentW - viewW);
                if (target < 0.0f) target = 0.0f;
                if (target > maxX) target = maxX;

                UI::SetScrollX(target);
                gScrollToCol = -1;
            }
        }
        UI::EndChild();

        if (gMsg.Length > 0) { UI::Separator(); UI::TextDisabled(gMsg); }

        UI::End();
    }

}
}
