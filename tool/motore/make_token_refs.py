"""Ids di riferimento coi tokenizer ufficiali di Hugging Face.

uso: python make_token_refs.py <cartella modelli> <fixture.json> <extra.json>
"""
import json
import random
import sys
from pathlib import Path

from tokenizers import Tokenizer

sys.path.insert(0, str(Path(__file__).parent))
from sentences import PROMPTS, SENTENCES  # noqa: E402

models, fixture, extra = sys.argv[1:4]


def texts_small():
    out = list(SENTENCES)
    return out


def texts_extra(seed=7, n=4000):
    rnd = random.Random(seed)
    alphabet = (
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        "àèéìòùÀÈÉÌÒÙçñüöäßøåæœ"
        "    \t\n.,;:!?'\"«»“”‘’()[]{}-–—_/\\@#%&*+=<>|~^`$€£¥•…"
        " ​́̀̈ﬁﬀ①Ｆ½²"
        "😀👍🏽🇮🇹❤️👨‍👩‍👧"
        "ελληνικάрусский日本語한국어العربية"
    )
    words = []
    for line in open(f"{models}/preciso/README.md", encoding="utf-8"):
        words += line.split()
    out = []
    for i in range(n):
        kind = i % 3
        if kind == 0:
            out.append("".join(rnd.choice(alphabet) for _ in range(rnd.randint(0, 60))))
        elif kind == 1:
            out.append(" ".join(rnd.choice(words) for _ in range(rnd.randint(1, 25))))
        else:
            s = rnd.choice(SENTENCES)
            # Pezzi di frasi vere, tagliati in punti qualsiasi.
            a = rnd.randint(0, len(s))
            b = rnd.randint(a, len(s))
            out.append(s[a:b] + rnd.choice(["", " ", "  ", "\n", "<mask>", "<table>", "😀"]) + s[:a])
    return out


def refs(texts):
    result = {}
    for model in ("leggero", "preciso"):
        tok = Tokenizer.from_file(f"{models}/{model}/tokenizer.json")
        rows = []
        for t in texts:
            for text in (t, PROMPTS[model] + t):
                rows.append({"text": text, "ids": tok.encode(text).ids})
        result[model] = rows
    return result


with open(fixture, "w", encoding="utf-8", newline="\n") as f:
    json.dump(refs(texts_small()), f, ensure_ascii=False, separators=(",", ":"))
with open(extra, "w", encoding="utf-8", newline="\n") as f:
    json.dump(refs(texts_extra()), f, ensure_ascii=False, separators=(",", ":"))
print("ok")
