namespace automata { namespace Helpers { namespace FileIO {

bool WriteTextFile(const string &in absPath, const string &in data) {
    try {
        IO::File f(absPath, IO::FileMode::Write);
        f.Write(data);
        f.Close();
        return true;
    } catch {
        return false;
    }
}

bool AppendLine(const string &in absPath, const string &in line) {
    try {
        IO::FileMode mode = IO::FileExists(absPath) ? IO::FileMode::Append : IO::FileMode::Write;
        IO::File f(absPath, mode);
        f.Write(line + "\n");
        f.Close();
        return true;
    } catch {
        return false;
    }
}

void DeleteIfExists(const string &in absPath) {
    try {
        if (IO::FileExists(absPath)) IO::Delete(absPath);
    } catch {}
}

string ReadTextFile(const string &in absPath) {
    try { return _IO::File::ReadFileToEnd(absPath, false); } catch { return ""; }
}

Json::Value@ ReadJson(const string &in absPath) {
    if (absPath.Length == 0) return null;
    try {
        if (!IO::FileExists(absPath)) return null;
    } catch {
        return null;
    }
    string txt = ReadTextFile(absPath);
    if (txt.Length == 0) return null;
    try { return Json::Parse(txt); } catch { return null; }
}

bool WriteJson(const string &in absPath, Json::Value@ v, bool pretty = false) {
    return WriteTextFile(absPath, Json::Write(v, pretty));
}

}}}
