import argparse
import bisect
import os

parser = argparse.ArgumentParser(description="Process log statements in code files.")
parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose output of all log modifications.")
args = parser.parse_args()

DEFAULT_PARAMS = ['""', "LogLevel::Info", "-1", '""']

KEYWORDS = {
    "if", "else", "for", "while", "switch", "case", "default", "do", "break", "continue", "return",
    "try", "catch", "throw", "namespace", "class", "enum", "struct", "interface", "funcdef",
}

def build_line_starts(text):
    starts = [0]
    for i, ch in enumerate(text):
        if ch == "\n":
            starts.append(i + 1)
    return starts

def index_to_line(line_starts, idx):
    return bisect.bisect_right(line_starts, idx)

def mask_non_code(text):
    out = list(text)
    n = len(text)
    i = 0
    in_line = False
    in_block = False
    in_str = False
    in_char = False
    escape = False

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if in_line:
            if ch == "\n":
                in_line = False
            else:
                out[i] = " "
            i += 1
            continue

        if in_block:
            if ch == "*" and nxt == "/":
                out[i] = " "
                if i + 1 < n:
                    out[i + 1] = " "
                in_block = False
                i += 2
            else:
                if ch != "\n":
                    out[i] = " "
                i += 1
            continue

        if in_str:
            if ch != "\n":
                out[i] = " "
            if escape:
                escape = False
            else:
                if ch == "\\":
                    escape = True
                elif ch == '"':
                    in_str = False
            i += 1
            continue

        if in_char:
            if ch != "\n":
                out[i] = " "
            if escape:
                escape = False
            else:
                if ch == "\\":
                    escape = True
                elif ch == "'":
                    in_char = False
            i += 1
            continue

        if ch == "/" and nxt == "/":
            out[i] = " "
            if i + 1 < n:
                out[i + 1] = " "
            in_line = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            out[i] = " "
            if i + 1 < n:
                out[i + 1] = " "
            in_block = True
            i += 2
            continue
        if ch == '"':
            in_str = True
            out[i] = " "
            i += 1
            continue
        if ch == "'":
            in_char = True
            out[i] = " "
            i += 1
            continue

        i += 1

    return "".join(out)

def is_ident_start(ch):
    return ch.isalpha() or ch == "_"

def is_ident_char(ch):
    return ch.isalnum() or ch == "_"

def skip_ws(text, idx):
    n = len(text)
    while idx < n and text[idx].isspace():
        idx += 1
    return idx

def find_matching_paren(text, start_idx):
    n = len(text)
    i = start_idx + 1
    depth = 1
    in_line = False
    in_block = False
    in_str = False
    in_char = False
    escape = False

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if in_line:
            if ch == "\n":
                in_line = False
            i += 1
            continue

        if in_block:
            if ch == "*" and nxt == "/":
                in_block = False
                i += 2
            else:
                i += 1
            continue

        if in_str:
            if escape:
                escape = False
            else:
                if ch == "\\":
                    escape = True
                elif ch == '"':
                    in_str = False
            i += 1
            continue

        if in_char:
            if escape:
                escape = False
            else:
                if ch == "\\":
                    escape = True
                elif ch == "'":
                    in_char = False
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        if ch == '"':
            in_str = True
            i += 1
            continue
        if ch == "'":
            in_char = True
            i += 1
            continue

        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1

    return -1

def split_args(arg_text):
    params = []
    buf = []
    depth_paren = 0
    depth_brack = 0
    depth_brace = 0
    in_line = False
    in_block = False
    in_str = False
    in_char = False
    escape = False
    i = 0
    n = len(arg_text)

    while i < n:
        ch = arg_text[i]
        nxt = arg_text[i + 1] if i + 1 < n else ""

        if in_line:
            if ch == "\n":
                in_line = False
            i += 1
            continue

        if in_block:
            if ch == "*" and nxt == "/":
                in_block = False
                i += 2
            else:
                i += 1
            continue

        if in_str:
            buf.append(ch)
            if escape:
                escape = False
            else:
                if ch == "\\":
                    escape = True
                elif ch == '"':
                    in_str = False
            i += 1
            continue

        if in_char:
            buf.append(ch)
            if escape:
                escape = False
            else:
                if ch == "\\":
                    escape = True
                elif ch == "'":
                    in_char = False
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        if ch == '"':
            in_str = True
            buf.append(ch)
            i += 1
            continue
        if ch == "'":
            in_char = True
            buf.append(ch)
            i += 1
            continue

        if ch == "(":
            depth_paren += 1
        elif ch == ")":
            if depth_paren > 0:
                depth_paren -= 1
        elif ch == "[":
            depth_brack += 1
        elif ch == "]":
            if depth_brack > 0:
                depth_brack -= 1
        elif ch == "{":
            depth_brace += 1
        elif ch == "}":
            if depth_brace > 0:
                depth_brace -= 1

        if ch == "," and depth_paren == 0 and depth_brack == 0 and depth_brace == 0:
            params.append("".join(buf).strip())
            buf = []
            i += 1
            continue

        buf.append(ch)
        i += 1

    trailing = "".join(buf).strip()
    if trailing or arg_text.strip():
        params.append(trailing)
    return params

def find_function_markers(clean_text):
    markers = {}
    i = 0
    n = len(clean_text)
    while i < n:
        ch = clean_text[i]
        if is_ident_start(ch):
            start = i
            i += 1
            while i < n and is_ident_char(clean_text[i]):
                i += 1
            name = clean_text[start:i]
            if name in KEYWORDS:
                continue
            j = skip_ws(clean_text, i)
            if j >= n or clean_text[j] != "(":
                continue
            end_paren = find_matching_paren(clean_text, j)
            if end_paren == -1:
                continue
            k = skip_ws(clean_text, end_paren + 1)
            if clean_text[k:k + 5] == "const" and (k + 5 == n or not is_ident_char(clean_text[k + 5])):
                k = skip_ws(clean_text, k + 5)
            if k < n and clean_text[k] == "{":
                if k not in markers:
                    markers[k] = name
                i = k + 1
                continue
        else:
            i += 1
    return markers

def build_function_ranges(clean_text):
    markers = find_function_markers(clean_text)
    ranges = []
    func_stack = []
    brace_depth = 0
    n = len(clean_text)
    for i, ch in enumerate(clean_text):
        if ch == "{":
            brace_depth += 1
            if i in markers:
                func_stack.append({"name": markers[i], "start": i, "depth": brace_depth})
        elif ch == "}":
            if func_stack and func_stack[-1]["depth"] == brace_depth:
                func = func_stack.pop()
                func["end"] = i
                ranges.append(func)
            brace_depth -= 1
            if brace_depth < 0:
                brace_depth = 0
    return ranges

def function_name_for_pos(ranges, pos):
    best = None
    for r in ranges:
        if r["start"] <= pos <= r["end"]:
            if best is None or r["start"] >= best["start"]:
                best = r
    return best["name"] if best else "UnknownFunction"

def clean_and_update_params(params, line_no, func_name):
    params = [p.strip() for p in params if p is not None]
    while len(params) < 4:
        params.append(DEFAULT_PARAMS[len(params)])
    params[2] = str(line_no)
    params[3] = f'"{func_name}"'
    if len(params) >= 2 and params[1].strip() == "":
        params[1] = DEFAULT_PARAMS[1]
    return params

def iter_log_calls(text):
    n = len(text)
    i = 0
    in_line = False
    in_block = False
    in_str = False
    in_char = False
    escape = False

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if in_line:
            if ch == "\n":
                in_line = False
            i += 1
            continue

        if in_block:
            if ch == "*" and nxt == "/":
                in_block = False
                i += 2
            else:
                i += 1
            continue

        if in_str:
            if escape:
                escape = False
            else:
                if ch == "\\":
                    escape = True
                elif ch == '"':
                    in_str = False
            i += 1
            continue

        if in_char:
            if escape:
                escape = False
            else:
                if ch == "\\":
                    escape = True
                elif ch == "'":
                    in_char = False
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        if ch == '"':
            in_str = True
            i += 1
            continue
        if ch == "'":
            in_char = True
            i += 1
            continue

        if is_ident_start(ch):
            start = i
            i += 1
            while i < n and is_ident_char(text[i]):
                i += 1
            token = text[start:i]
            if token == "log":
                prev = text[start - 1] if start > 0 else ""
                if prev == ".":
                    continue
                j = skip_ws(text, i)
                if j < n and text[j] == "(":
                    end_paren = find_matching_paren(text, j)
                    if end_paren != -1:
                        k = skip_ws(text, end_paren + 1)
                        if k < n and text[k] == ";":
                            end_call = k + 1
                        else:
                            end_call = end_paren + 1
                        yield start, j, end_paren, end_call
                        i = end_call
                        continue
            continue

        i += 1

def process_text(text, verbose=False):
    line_starts = build_line_starts(text)
    clean = mask_non_code(text)
    func_ranges = build_function_ranges(clean)
    out = []
    last = 0
    for start, open_paren, end_paren, end_call in iter_log_calls(text):
        segment = text[start:end_call]
        arg_text = text[open_paren + 1:end_paren]
        line_no = index_to_line(line_starts, start)
        func_name = function_name_for_pos(func_ranges, start)
        try:
            params = split_args(arg_text)
            updated = clean_and_update_params(params, line_no, func_name)
            new_call = f'log({", ".join(updated)})'
            has_semicolon = text[end_paren + 1:end_call].strip().startswith(";")
            if has_semicolon:
                new_call += ";"
            newlines = segment.count("\n")
            if newlines:
                new_call += "\n" * newlines
            out.append(text[last:start])
            out.append(new_call)
            last = end_call
            if verbose:
                print(f"Updated log call at line {line_no}: {new_call.strip()}")
        except Exception as e:
            if verbose:
                print(f"Failed to parse log call at line {line_no}: {e}")
    out.append(text[last:])
    return "".join(out)

def modify_log_statements(file_path, verbose):
    try:
        with open(file_path, "r", encoding="utf-8") as file:
            text = file.read()
    except UnicodeDecodeError:
        return False

    new_text = process_text(text, verbose)
    if new_text != text:
        with open(file_path, "w", encoding="utf-8") as file:
            file.write(new_text)
        return True
    return False

def process_directory(directory, verbose):
    include_extensions = {".as"}
    exclude_extensions = {".dll", ".exe", ".bin"}

    for root, dirs, files in os.walk(directory):
        for file in files:
            ext = os.path.splitext(file)[1]
            if ext in include_extensions and ext not in exclude_extensions:
                file_path = os.path.join(root, file)
                if modify_log_statements(file_path, verbose):
                    if verbose:
                        print(f"Found and updated instances in: {file_path}")
            else:
                if verbose:
                    print(f"Skipping file: {os.path.join(root, file)}")

if __name__ == "__main__":
    process_directory("./src", args.verbose)
