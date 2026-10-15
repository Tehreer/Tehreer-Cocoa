#!/usr/bin/env python3
"""Formats the calls that have two or more arguments in the lines added by the git diff (or in
every line of a new file). A call that fits in 100 columns is put on one line. A call that does not
fit gets the modern style: the opening parenthesis ends its line, every argument has a line of its
own, and the closing parenthesis starts a line. Run it from the root of the repository."""
import re, subprocess, sys, os

M = '\u0001'
LIMIT = 100
KEYWORDS = {'if', 'while', 'guard', 'switch', 'for', 'return', 'in', 'case', 'catch', 'where', 'else', 'let', 'var', 'throw', 'try', 'await', 'is', 'as', 'repeat', 'defer'}

def classify(t):
    """Returns a list: 'c' code, 's' string, 'm' comment, for each character."""
    n = len(t)
    cls = ['c'] * n
    i = 0
    while i < n:
        ch = t[i]
        if t.startswith('//', i):
            j = t.find('\n', i)
            j = n if j < 0 else j
            for k in range(i, j): cls[k] = 'm'
            i = j
        elif t.startswith('/*', i):
            j = t.find('*/', i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j): cls[k] = 'm'
            i = j
        elif t.startswith('"""', i):
            j = t.find('"""', i + 3)
            j = n if j < 0 else j + 3
            for k in range(i, j): cls[k] = 's'
            i = j
        elif ch == '"':
            j = i + 1
            depth = 0
            while j < n:
                if t[j] == '\\' and j + 1 < n:
                    if t[j + 1] == '(':
                        depth += 1
                        j += 2
                        continue
                    j += 2
                    continue
                if t[j] == '(' and depth > 0: depth += 1
                elif t[j] == ')' and depth > 0: depth -= 1
                elif t[j] == '"' and depth == 0:
                    break
                j += 1
            for k in range(i, min(j + 1, n)): cls[k] = 's'
            i = j + 1
        else:
            i += 1
    return cls

def line_bounds(t, pos):
    s = t.rfind('\n', 0, pos) + 1
    e = t.find('\n', pos)
    return s, (len(t) if e < 0 else e)

def indent_of(line):
    line = line.replace(M, '')
    return len(line) - len(line.lstrip(' '))

def match_paren(t, cls, i):
    d = 0
    for j in range(i, len(t)):
        if cls[j] != 'c': continue
        if t[j] == '(': d += 1
        elif t[j] == ')':
            d -= 1
            if d == 0: return j
    return -1

def split_args(t, cls, a, b):
    parts = []
    depth = 0
    angle = 0
    start = a
    for j in range(a, b):
        if cls[j] != 'c': continue
        c = t[j]
        if c in '([{': depth += 1
        elif c in ')]}': depth -= 1
        elif c == '<' and j > 0 and (t[j-1].isalnum() or t[j-1] == '_') and j + 1 < len(t) and t[j+1] not in ' =':
            angle += 1
        elif c == '>' and angle > 0 and t[j-1] != '-':
            angle -= 1
        elif c == ',' and depth == 0 and angle == 0:
            parts.append(t[start:j]); start = j + 1
    parts.append(t[start:b])
    return parts

DECL = re.compile(r'(^|[\s])(func|subscript)\b')
INIT_DECL = re.compile(r'(^|\s)init[?!]?\s*$')

def is_call(t, cls, i):
    if i == 0 or cls[i-1] != 'c': return False
    p = t[i-1]
    if not (p.isalnum() or p in '_>)]?!'): return False
    ls, le = line_bounds(t, i)
    prefix = t[ls:i].replace(M, '')
    stripped = prefix.lstrip()
    if stripped.startswith(('case ', 'default:', '@', '#')): return False
    if DECL.search(prefix): return False
    # identifier before the paren
    k = i - 1
    while k >= ls and (t[k].isalnum() or t[k] in '_'): k -= 1
    ident = t[k+1:i]
    if k >= ls and t[k] in '@#': return False
    if ident in KEYWORDS: return False
    if ident == 'init' and not (k >= ls and t[k] == '.'):
        return False
    if re.search(r'(^|\s)(enum|struct|class|protocol|typealias|extension)\b', prefix) and not '=' in prefix:
        return False
    return True

def reformat(t, only_marked):
    cls = classify(t)
    i = 0
    n = len(t)
    while i < n:
        if cls[i] == 'c' and t[i] == '(' and is_call(t, cls, i):
            j = match_paren(t, cls, i)
            if j > 0:
                ls, le = line_bounds(t, i)
                line = t[ls:le]
                inner = t[i+1:j]
                ok = (not only_marked) or line.startswith(M)
                if ok and '//' not in ''.join(c for c, k in zip(t[i+1:j], cls[i+1:j]) if k == 'm' or c == '/' and False) and all(k != 'm' for k in cls[i+1:j]):
                    parts = split_args(t, cls, i+1, j)
                    parts_s = [p.replace(M, '').strip() for p in parts]
                    if len(parts_s) >= 2 and all(parts_s):
                        base = indent_of(line)
                        # the rest of the line that holds the closing parenthesis
                        _, ce = line_bounds(t, j)
                        suffix = t[j+1:ce].replace(M, '')
                        prefix = t[ls:i].replace(M, '')
                        joined = '(' + ', '.join(parts_s) + ')'
                        fits = ('\n' not in joined) and len(prefix) + len(joined) + len(suffix) <= LIMIT
                        if fits:
                            new = joined
                        else:
                            pad = ' ' * (base + 4)
                            out = []
                            for p in parts_s:
                                lines = p.split('\n')
                                first = lines[0]
                                rest = [(M + ' ' * 4 + x) if x.strip() else x for x in lines[1:]]
                                out.append(M + pad + first + ('\n' + '\n'.join(rest) if rest else ''))
                            new = '(\n' + ',\n'.join(out) + '\n' + M + ' ' * base + ')'
                        if t[i:j+1].replace(M, '') != new.replace(M, ''):
                            t = t[:i] + new + t[j+1:]
                            cls = classify(t)
                            n = len(t)
                            i += 1
                            continue
        i += 1
    return t

def added_lines(path):
    out = subprocess.run(['git', 'diff', '-U0', 'HEAD', '--', path], capture_output=True, text=True).stdout
    lines = set()
    for m in re.finditer(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', out, re.M):
        a = int(m.group(1)); c = int(m.group(2) or 1)
        lines.update(range(a, a + c))
    return lines

def process(path, is_new):
    src = open(path).read()
    ls = src.split('\n')
    marked = set(range(1, len(ls) + 1)) if is_new else added_lines(path)
    if not marked: return False
    # skip license header
    text = '\n'.join((M + l if (i + 1) in marked else l) for i, l in enumerate(ls))
    # loop to a fixed point
    for _ in range(50):
        new = reformat(text, True)
        if new == text: break
        text = new
    result = text.replace(M, '')
    if result != src:
        open(path, 'w').write(result)
        return True
    return False

if __name__ == '__main__':
    new_files = set()
    out = subprocess.run(['git', 'status', '--short', '--untracked-files=all'], capture_output=True, text=True).stdout.splitlines()
    files = []
    for l in out:
        st, p = l[:2], l[3:]
        if not p.endswith('.swift') or p.startswith('.build') or not os.path.exists(p) or p.startswith('Libraries/'): continue
        files.append((p, 'A' in st or '?' in st))
    changed = 0
    for p, is_new in files:
        if len(sys.argv) > 1 and p not in sys.argv[1:]: continue
        if process(p, is_new):
            changed += 1; print('formatted', p)
    print(changed)
