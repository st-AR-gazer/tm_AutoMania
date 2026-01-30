namespace UiNav {
    void _ParseWildcardHintsToken(const string &in tok, int[] &out outHints) {
        outHints.Resize(0);

        int pos = 0;
        while (true) {
            int lRel = tok.SubStr(pos).IndexOf("<");
            if (lRel < 0) break;
            int l = pos + lRel;

            int rRel = tok.SubStr(l + 1).IndexOf(">");
            if (rRel < 0) break;
            int r = (l + 1) + rRel;

            string inner = tok.SubStr(l + 1, r - (l + 1)).Trim();
            if (inner.Length > 0) {
                inner = inner.Replace("|", ",");
                string[] parts = inner.Split(",");
                for (uint i = 0; i < parts.Length; ++i) {
                    string s = parts[i].Trim();
                    if (s.Length == 0) continue;

                    bool numeric = true;
                    int sl = int(s.Length);
                    for (int j = 0; j < sl; ++j) {
                        string ch = s.SubStr(j, 1);
                        if (ch < "0" || ch > "9") { numeric = false; break; }
                    }
                    if (numeric) outHints.InsertLast(Text::ParseInt(s));
                }
            }
            pos = r + 1;
        }

        int lb = tok.IndexOf("[");
        int rbRel = -1;
        
        if (lb < 0) lb = tok.IndexOf("{");
        
        if (lb >= 0) {
            string close = (tok.SubStr(lb, 1) == "[") ? "]" : "}";
            rbRel = tok.SubStr(lb + 1).IndexOf(close);
            if (rbRel >= 0) {
                int rb = (lb + 1) + rbRel;
                string inner = tok.SubStr(lb + 1, rb - (lb + 1)).Replace("|", ",");
                string[] parts = inner.Split(",");
                for (uint i = 0; i < parts.Length; ++i) {
                    string s = parts[i].Trim();
                    if (s.Length == 0) continue;

                    bool numeric = true;
                    int sl = int(s.Length);
                    for (int j = 0; j < sl; ++j) {
                        string ch = s.SubStr(j, 1);
                        if (ch < "0" || ch > "9") { numeric = false; break; }
                    }
                    if (numeric) outHints.InsertLast(Text::ParseInt(s));
                }
            }
        }
    }

    void _ParsePathEx(const string &in spec,
                      array<int> &out parts,
                      array<bool> &out wildcards,
                      array<array<int>> &out hints)
    {
        parts.Resize(0);
        wildcards.Resize(0);
        hints.Resize(0);

        string[] tokens = spec.Split("/");
        for (uint i = 0; i < tokens.Length; ++i) {
            string s = tokens[i].Trim();
            if (s.Length == 0) {
                parts.InsertLast(0);
                wildcards.InsertLast(true);
                array<int> h;
                hints.InsertLast(h);
            } else if (s.SubStr(0, 1) == "*") {
                parts.InsertLast(0);
                wildcards.InsertLast(true);
                array<int> h;
                _ParseWildcardHintsToken(s, h);
                hints.InsertLast(h);
            } else {
                parts.InsertLast(Text::ParseInt(s));
                wildcards.InsertLast(false);
                array<int> h;
                hints.InsertLast(h);
            }
        }
    }

    bool SpecHasWildcard(const string &in spec) { return spec.IndexOf("*") >= 0; }
}