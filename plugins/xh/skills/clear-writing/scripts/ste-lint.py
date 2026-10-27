#!/usr/bin/env python3
"""Heuristic prose linter for the clear-writing skill.

Scores a Markdown or plain-text file for the mechanical, lintable subset of
ASD-STE100 Simplified Technical English plus the XH house rule against em
dashes. Output is violations per 100 words. Lower is cleaner. The number is a
signal for a rewrite loop, not a certification.

    python3 ste-lint.py draft.md              one line per file
    python3 ste-lint.py --json draft.md       full breakdown with matched spans
    python3 ste-lint.py --fail-over 2.5 *.md  exit 1 if any file scores over 2.5
    cat draft.md | python3 ste-lint.py        read from stdin, JSON out

Derived from ste-lint.py in the asd-ste100 kit by Ege Chelebi (MIT). See
NOTICE.md in the parent directory for the license and the upstream revision.

Markdown handling: YAML frontmatter and fenced code are skipped, inline code
becomes a placeholder word so sentences still split, emphasis markers and
blockquote markers are removed, wrapped lines are joined, each list item is
its own paragraph, and table rows count toward words and word-level checks
but never as sentences or paragraphs.
"""
import re, sys, json, glob, os

# Score v4 (XH). Not comparable to earlier versions. v4 counts em dashes only
# outside code and adds " -- " as an em-dash surrogate, moves the sentence cap
# to 25 words (the ASD-STE100 descriptive cap) and reports 21 to 25 as a
# marker, ignores table rows for the sentence and paragraph rules, and drops
# "provide" from the banned list.
SCORE_VERSION = 4

MARKETING = ["seamless","seamlessly","robust","powerful","cutting-edge","effortless","effortlessly",
    "world-class","next-generation","revolutionary","blazing","lightning-fast","elegant","delightful",
    "turnkey","best-in-class","state-of-the-art","game-changing","first-class","battle-tested",
    "enterprise-grade","supercharge","unlock","unleash","empower","empowers"]
BANNED = ["begin","begins","commence","commences","initiate","initiates","originate",
    "utilize","utilizes","utilizing","leverage","leverages","leveraging","facilitate","facilitates",
    "ensure","ensures","ensuring","prior to","subsequent to","obtain","obtains","acquire","acquires",
    "demonstrate","demonstrates","additionally","furthermore","moreover","comprehensive","comprehensively",
    "utilization","aforementioned","henceforth","therein","whilst","amongst","numerous","myriad","plethora",
    "in order to","a variety of","in the event that","due to the fact that","it is important to note"]
PHRASAL = ["spin up","spin down","reach out","dive into","dives into","diving into","kick off","kicks off","kicking off","kicked off",
    "roll out","rolls out","rolling out","rolled out","tear down","ramp up","circle back","drill down","spun up","reaching out",
    "pick up","picks up","picked up","leave off","leaves off","left off","figure out","figures out","end up","ends up"]
MODAL_HEDGE = ["it is important to note","it should be noted","it is worth noting","please note that",
    "as mentioned","as noted above"]
BE = r"(?:am|is|are|was|were|be|been|being)"
PP_IRREG = r"(?:done|made|sent|read|built|kept|held|set|put|run|written|shown|given|taken|found|got|gotten|seen|known|thrown|drawn)"
# Rule 3.3: a past participle used as an adjective is not passive. These
# stative participles only count as passive when a by-agent follows.
STATIVE = r"(?:closed|opened?|damaged|completed?|installed|connected|required|expected|configured|enabled|disabled|deprecated|supported|unchanged|unrelated|related|based|named|nested|sorted|limited|marked|scoped|undefined|unused|documented|exported|whitelisted|allowlisted|blocklisted|restricted|reserved|protected|registered)"
# "by default", "by design": the word after "by" is a manner, not an agent.
NOT_AGENT = r"(?:default|design|hand|name|far|itself|themselves|then|now|contrast|comparison|extension|definition|nature|way|reference|value|id|key|index|position|convention)"
FUNC_WORDS = set("""a an the this that these those of for to in on at by with from as and or but if
when then than not no is are was were be been being am do does did has have had will would can could
may might must should shall it its their your our his her they we you i""".split())

CODE_TOKEN = "CODE"
LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
HEADING = re.compile(r"^\s*#{1,6}\s+")
TABLE_ROW = re.compile(r"^\s*\|")
FENCE = re.compile(r"```.*?```", re.S)

def strip_frontmatter(t):
    """Drop a leading YAML frontmatter block. It is metadata for a harness,
    not prose for a reader."""
    return re.sub(r"\A---\n.*?\n---\n", "", t, count=1, flags=re.S)

def strip_code(t):
    """Remove fenced code. Replace inline code with a placeholder word, so a
    sentence that ends or starts with an identifier still splits correctly."""
    t = FENCE.sub(" ", t)
    t = re.sub(r"`[^`]{0,200}`", CODE_TOKEN, t)
    return t

def strip_markup(s):
    """Remove emphasis and blockquote markers from one line, so a sentence
    that ends in `.**` or starts after `> ` still splits."""
    s = re.sub(r"^\s*(?:>\s*)+", "", s)
    s = re.sub(r"(\*\*|__)", "", s)
    s = re.sub(r"(?<![\w*])\*(?=\S)|(?<=\S)\*(?![\w*])", "", s)
    return s

def logical_lines(text):
    """Join wrapped lines, so a sentence that spans a line break is scored as
    one sentence. A heading, a table row, and a list item (with its
    continuation lines) each stand alone. Returns (text, is_table) pairs."""
    out, buf = [], []
    def flush():
        if buf: out.append((" ".join(buf), False)); buf.clear()
    for line in text.split("\n"):
        s = strip_markup(line.strip())
        if not s: flush(); continue
        if TABLE_ROW.match(line):
            flush(); out.append((s, True)); continue
        if HEADING.match(s):
            flush(); out.append((s, False)); continue
        if LIST_ITEM.match(s): flush()
        buf.append(s)
    flush()
    return out

def split_sentences(s):
    s = re.sub(r"^\s*#{1,6}\s*", "", s)
    s = re.sub(r"^\s*(?:[-*+]|\d+[.)])\s+", "", s)
    parts = re.split(r"(?<=[.!?:])\s+(?=[A-Z0-9\"'\-(])", s)
    return [p.strip() for p in parts if p.strip()]

def sentences(text, tables=True):
    """All sentences. With tables=False, table rows are left out, for the
    rules where a row is a label and not a sentence."""
    out = []
    for s, is_table in logical_lines(text):
        if is_table and not tables: continue
        out.extend(split_sentences(s))
    return out

def paragraphs(raw):
    """Prose paragraphs, after fenced code is removed. A fence is a paragraph
    break. Each list item is its own paragraph. A table is not a paragraph."""
    t = FENCE.sub("\n\n", raw)
    t = re.sub(r"^[ \t]*```.*$", "\n", t, flags=re.M)   # a fence with no partner
    t = re.sub(r"`[^`]{0,200}`", CODE_TOKEN, t)
    out = []
    for chunk in re.split(r"\n\s*\n", t):
        lines = [l for l in chunk.split("\n") if l.strip()]
        if not lines or all(TABLE_ROW.match(l) for l in lines): continue
        item = []
        for line in lines:
            if TABLE_ROW.match(line): continue
            if LIST_ITEM.match(line) and item:
                out.append("\n".join(item)); item = []
            item.append(line)
        if item: out.append("\n".join(item))
    return out

def wc(s):
    return len([w for w in re.findall(r"[A-Za-z0-9][A-Za-z0-9'\-/]*", s)])

def count_ci(text, phrases):
    n = 0; hits = []
    low = text.lower()
    for ph in phrases:
        for m in re.finditer(r"(?<![a-z])" + re.escape(ph) + r"(?![a-z])", low):
            n += 1; hits.append(ph)
    return n, hits

def noun_trains(text):
    """Runs of 4+ consecutive non-function lowercase words (Rule 2.1 proxy).
    Heuristic marker only. Proper nouns break a run, the leading word of each
    sentence is skipped, and the count stays out of the total."""
    hits = []
    for s in sentences(text, tables=False):
        words = re.findall(r"[A-Za-z][A-Za-z'\-]*", s)[1:]
        run = []
        for w in words + [""]:
            if w and w.lower() not in FUNC_WORDS and not w[0].isupper():
                run.append(w)
            else:
                if len(run) >= 4: hits.append(" ".join(run))
                run = []
    return hits

def lint(text):
    raw = strip_frontmatter(text)
    text = strip_code(raw)
    all_sents = sentences(text)
    prose_sents = sentences(text, tables=False)
    words = sum(wc(s) for s in all_sents) or 1
    v = {}
    hits = {}   # category -> matched spans, for the fix loop
    longs = [(wc(s), s) for s in prose_sents if wc(s) > 25]
    mids = [(wc(s), s) for s in prose_sents if 20 < wc(s) <= 25]
    v["long_sentence(>25w)"] = len(longs)
    v["semicolon"] = text.count(";")
    hits["contraction"] = re.findall(r"\b\w+['’](?:t|re|ve|ll|d|m)\b", text, re.I) \
        + re.findall(r"\b(?:it|that|there|here|what|who|he|she|let|where|how|when|why|one)['’]s\b", text, re.I)
    v["contraction"] = len(hits["contraction"])
    def grab(cat, pattern, keep=None):
        found = [m.group(0) for m in re.finditer(pattern, text, re.I)]
        if keep: found = [f for f in found if keep(f)]
        hits[cat] = found
        return len(found)
    v["passive_voice"] = grab("passive_voice", rf"\b{BE}\s+(?:\w+ed|{PP_IRREG})\b(?!-)",
        keep=lambda f: not re.fullmatch(STATIVE, f.split()[-1], re.I)) \
        + grab("passive_voice_by", rf"\b{BE}\s+{STATIVE}\s+by\b(?!\s+{NOT_AGENT}\b)")
    v["complex_tense"] = grab("complex_tense",
        rf"\b(?:(?:may|might|could|would|should|must|will|shall|can)\s+)?(?:have|has|had)\s+(?:been\s+)?(?:\w+ed|{PP_IRREG})\b(?!-)")
    v["ing_main_verb"] = grab("ing_main_verb", rf"\b{BE}\s+\w+ing\b")
    v["nominalization"] = grab("nominalization",
        r"\b(?:perform(?:s|ed)?|conduct(?:s|ed)?|carry out|carries out|make use of|makes use of)\b|\b\w{4,}(?:tion|ment|ance|ence)\s+of\b")
    v["phrasal_verb"], hits["phrasal_verb"] = count_ci(text, PHRASAL)
    v["banned_word"], hits["banned_word"] = count_ci(text, BANNED)
    v["marketing_adjective"], hits["marketing_adjective"] = count_ci(text, MARKETING)
    v["modal_hedge"], hits["modal_hedge"] = count_ci(text, MODAL_HEDGE)
    v["long_paragraph(>6s)"] = sum(1 for p in paragraphs(raw) if len(sentences(p, tables=False)) > 6)
    # XH house rule: no em dashes, en dashes, or " -- " standing in for one.
    # Counted outside code only. Em dashes inside fences are reported apart.
    v["em_dash"] = text.count("—") + text.count("–") + len(re.findall(r"(?<=\s)--(?=\s)", text))
    em_in_code = sum(b.count("—") + b.count("–") for b in FENCE.findall(raw))
    trains = noun_trains(text)
    total = sum(v.values())
    return {
        "score_version": SCORE_VERSION,
        "words": words, "sentences": len(all_sents),
        "violations": v, "total": total,
        "total_per100w": round(total*100.0/words, 2),
        "sentence_21_to_25w(marker)": len(mids),
        "em_dash_in_code(marker)": em_in_code,
        "noun_train(>=4w,marker)": len(trains),
        "longest_sentence_words": max((wc(s) for s in prose_sents), default=0),
        "sample_noun_train": trains[:3],
        "sample_long_sentence": ["{}w: {}".format(n, s[:70]) for n, s in
                                 sorted(longs, key=lambda x: -x[0])[:2]],
        "sample_hits": {k: list(dict.fromkeys(h))[:6] for k, h in hits.items() if h},
    }

if __name__ == "__main__":
    args = sys.argv[1:]
    if "-h" in args or "--help" in args:
        print(__doc__.strip()); sys.exit(0)
    as_json = "--json" in args
    fail_over = None
    if "--fail-over" in args:
        i = args.index("--fail-over")
        fail_over = float(args[i + 1])
        del args[i:i + 2]
    files = [a for a in args if a != "--json"]
    worst = 0.0
    if not files:
        sys.stdin.reconfigure(encoding="utf-8")
        r = lint(sys.stdin.read())
        print(json.dumps(r, indent=2))
        worst = r["total_per100w"]
    else:
        exp = []
        for f in files: exp += sorted(glob.glob(f)) if any(c in f for c in "*?[") else [f]
        for f in exp:
            with open(f, encoding="utf-8") as fh: r = lint(fh.read())
            worst = max(worst, r["total_per100w"])
            if as_json:
                print(json.dumps({"file": f, **r}, indent=2))
            else:
                print(f"{os.path.basename(f):32} words={r['words']:4d} total={r['total']:3d} per100w={r['total_per100w']:6.2f} em_dash={r['violations']['em_dash']:2d}")
    if fail_over is not None and worst > fail_over:
        sys.exit(1)
