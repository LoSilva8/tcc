# Converte o docx do TCC (export do Google Docs) em docs/TCC.md sem precisar de pandoc.
# Uso: python docs/docx2md.py <TCC.docx> docs/TCC.md
import zipfile, sys, re
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
src, dst = sys.argv[1], sys.argv[2]
z = zipfile.ZipFile(src)
root = ET.fromstring(z.read("word/document.xml"))
body = root.find(W + "body")

def on(el):
    # <w:b/> or <w:b w:val="1"> is on; w:val="0"/"false" is off
    return el is not None and el.get(W + "val", "1") not in ("0", "false")

def run_text(r):
    out = []
    for c in r:
        if c.tag == W + "t":
            out.append(c.text or "")
        elif c.tag == W + "tab":
            out.append("\t")
        elif c.tag in (W + "br", W + "cr"):
            out.append("  \n")
    return "".join(out)

def para_text(p):
    segs = []  # (text, bold, italic)
    for r in p.iter(W + "r"):
        t = run_text(r)
        if not t:
            continue
        rpr = r.find(W + "rPr")
        b = on(rpr.find(W + "b")) if rpr is not None else False
        i = on(rpr.find(W + "i")) if rpr is not None else False
        if segs and segs[-1][1] == b and segs[-1][2] == i:
            segs[-1] = (segs[-1][0] + t, b, i)
        else:
            segs.append((t, b, i))
    all_bold = bool(segs) and all(b for t, b, i in segs if t.strip())
    out = []
    for t, b, i in segs:
        if not t.strip():
            out.append(t); continue
        lead = t[:len(t) - len(t.lstrip())]; trail = t[len(t.rstrip()):]; core = t.strip()
        if i: core = f"*{core}*"
        if b and not all_bold: core = f"**{core}**"
        out.append(lead + core + trail)
    return "".join(out).strip(), all_bold

def para(p):
    ppr = p.find(W + "pPr")
    style = ""
    lvl = None
    if ppr is not None:
        ps = ppr.find(W + "pStyle")
        if ps is not None: style = ps.get(W + "val")
        np_ = ppr.find(W + "numPr")
        if np_ is not None:
            il = np_.find(W + "ilvl")
            lvl = int(il.get(W + "val")) if il is not None else 0
    text, all_bold = para_text(p)
    if not text:
        return None
    m = re.match(r"Heading(\d)", style)
    if m:
        return "#" * int(m.group(1)) + " " + text
    if style == "Title":
        return "# " + text
    if style == "Subtitle":
        return "*" + text + "*"
    if lvl is not None:
        return "  " * lvl + "- " + text
    if all_bold:
        return f"**{text}**"
    return text

def cell_text(tc):
    parts = [para_text(p)[0] for p in tc.iter(W + "p")]
    return "<br>".join(x for x in parts if x).replace("|", r"\|")

def table(tbl):
    rows = []
    for tr in tbl.findall(W + "tr"):
        rows.append([cell_text(tc) for tc in tr.findall(W + "tc")])
    if not rows:
        return None
    n = max(len(r) for r in rows)
    rows = [r + [""] * (n - len(r)) for r in rows]
    lines = ["| " + " | ".join(rows[0]) + " |", "|" + "---|" * n]
    lines += ["| " + " | ".join(r) + " |" for r in rows[1:]]
    return "\n".join(lines)

blocks = []
for el in body:
    if el.tag == W + "p":
        b = para(el)
    elif el.tag == W + "tbl":
        b = table(el)
    else:
        b = None
    if b:
        blocks.append(b)

# keep consecutive list items and pipe-table rows (typed as plain paragraphs) tight
def kind(b):
    s = b.lstrip()
    return "li" if s.startswith("- ") else "tr" if s.startswith("|") else None

out = []
for b in blocks:
    if out and kind(b) and kind(b) == kind(out[-1].split("\n")[-1]):
        out[-1] += "\n" + b
    else:
        out.append(b)
text = "\n\n".join(out) + "\n"
# the export starts with claude.ai project-page chrome; the thesis begins at its title
start = text.find("# PYADVENTURE:")
if start > 0:
    text = text[start:]
open(dst, "w", encoding="utf-8", newline="\n").write(text)
