namespace UiNav {
    bool Exists(const string &in spec, uint overlay = 16) {
        return ResolvePath(spec, overlay) !is null;
    }

    bool PathExists(const string &in spec, uint overlay = 16) { return Exists(spec, overlay); }

    bool WaitForPath(const string &in spec, uint overlay = 16, int timeoutMs = 4000, int pollMs = 33) {
        uint until = Time::Now + uint(timeoutMs);
        while (Time::Now < until) {
            if (Exists(spec, overlay)) return true;
            yield(pollMs);
        }
        return false;
    }

    bool WaitForPathSmartGuarded(const string &in spec, const string &in guardStartsWith, uint overlay = 16, int timeoutMs = 4000, int pollMs = 33) {
        uint until = Time::Now + uint(timeoutMs);
        while (Time::Now < until) {
            if (ResolvePathSmartGuarded(spec, guardStartsWith, overlay) !is null) return true;
            if (ResolvePathSmartAnyRootGuarded(spec, guardStartsWith, overlay) !is null) return true;
            yield(pollMs);
        }
        return false;
    }
}