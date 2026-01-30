
namespace UiNav {

    bool ClickPath(const string &in spec, uint overlay = 16) {
        CControlBase@ n = ResolvePath(spec, overlay);
        if (n is null) return false;

        CControlQuad@ q = cast<CControlQuad>(n);
        if (q !is null) { q.OnAction(); return true; }

        CControlButton@ b = cast<CControlButton>(n);
        if (b !is null) { b.OnAction(); return true; }

        CGameControlCardGeneric@ card = cast<CGameControlCardGeneric>(n);
        if (card !is null) { card.OnAction(); return true; }

        uint len = _ChildrenLen(n);
        for (uint i = 0; i < len; ++i) {
            CControlBase@ ch = _ChildAt(n, i);
            if (ch is null) continue;

            CControlQuad@ q0 = cast<CControlQuad>(ch);
            if (q0 !is null) { q0.OnAction(); return true; }

            CControlButton@ b0 = cast<CControlButton>(ch);
            if (b0 !is null) { b0.OnAction(); return true; }

            CGameControlCardGeneric@ cg0 = cast<CGameControlCardGeneric>(ch);
            if (cg0 !is null) { cg0.OnAction(); return true; }
        }
        return false;
    }

    bool SetTextPath(const string &in spec, const string &in text, uint overlay = 16) {
        CControlBase@ n = ResolvePath(spec, overlay);
        if (n is null) return false;

        CControlEntry@ e = cast<CControlEntry>(n);
        if (e !is null) {
            CGameManialinkEntry@ ml = cast<CGameManialinkEntry>(e.Nod);
            if (ml is null) return false;
            ml.SetText(text, true);
            return true;
        }

        CControlFrame@ f = cast<CControlFrame>(n);
        if (f !is null) {
            CControlEntry@ e2 = cast<CControlEntry>(f.Nod);
            if (e2 !is null) {
                CGameManialinkEntry@ ml2 = cast<CGameManialinkEntry>(e2.Nod);
                if (ml2 is null) return false;
                ml2.SetText(text, true);
                return true;
            }
        }
        return false;
    }

    string ReadLabelAtPath(const string &in spec, uint overlay = 16) {
        CControlBase@ n = ResolvePath(spec, overlay);
        return ReadText(n);
    }

}