"""Vettori di riferimento con onnxruntime in Python e i tokenizer di Hugging Face.

uso: python make_vec_refs.py <cartella modelli>
Scrive <cartella>/embedding-reference.json.
"""
import json
import sys
from pathlib import Path
import time

import numpy as np
import onnxruntime as ort
from tokenizers import Tokenizer

sys.path.insert(0, str(Path(__file__).parent))
from sentences import PROMPTS, SENTENCES  # noqa: E402

models = sys.argv[1]

TOPICAL = [
    "Domani mattina vado in palestra a fare gambe.",
    "Stasera allenamento di corsa, dieci chilometri al parco.",
    "Devo comprare le proteine e le scarpe nuove per correre.",
    "Il cliente vuole la nuova schermata di login entro venerdì.",
    "Nella riunione abbiamo deciso di rifare il backend dell'app.",
    "Il bug della sincronizzazione va sistemato prima del rilascio.",
    "Per cena faccio la pasta al pomodoro con il basilico.",
    "Ricordarsi di comprare il pane, il latte e le uova.",
    "La ricetta della torta di mele della nonna è nel quaderno.",
]

DIMS = {"preciso": 256, "leggero": 384}
FILES = {"preciso": "model_q4.onnx", "leggero": "model_quantized.onnx"}


def embed(sess, tok, model, texts):
    enc = tok.encode_batch([PROMPTS[model] + t for t in texts])
    n = max(len(e.ids) for e in enc)
    ids = np.array([e.ids + [0 if model == "preciso" else 1] * (n - len(e.ids)) for e in enc], dtype=np.int64)
    mask = np.array([[1] * len(e.ids) + [0] * (n - len(e.ids)) for e in enc], dtype=np.int64)
    feeds = {"input_ids": ids, "attention_mask": mask}
    if model == "leggero":
        feeds["token_type_ids"] = np.zeros_like(ids)
        hidden = sess.run(["last_hidden_state"], feeds)[0]
        m = mask[:, :, None].astype(np.float32)
        v = (hidden * m).sum(1) / m.sum(1)
    else:
        v = sess.run(["sentence_embedding"], feeds)[0]
        print("  norma di sentence_embedding (768):", np.linalg.norm(v, axis=1)[:3])
    v = v[:, : DIMS[model]]
    return v / np.linalg.norm(v, axis=1, keepdims=True)


out = {}
for model in ("preciso", "leggero"):
    tok = Tokenizer.from_file(f"{models}/{model}/tokenizer.json")
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = 4
    opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    sess = ort.InferenceSession(f"{models}/{model}/{FILES[model]}", opts, providers=["CPUExecutionProvider"])
    texts = [s for s in SENTENCES if s.strip()] + TOPICAL
    batched = embed(sess, tok, model, texts)
    single = np.vstack([embed(sess, tok, model, [t]) for t in texts])
    print(model, "gruppo contro una alla volta, coseno minimo:", float((batched * single).sum(1).min()))
    t0 = time.perf_counter()
    for t in TOPICAL:
        embed(sess, tok, model, [t])
    print(model, "ms per frase (una alla volta):", (time.perf_counter() - t0) * 1000 / len(TOPICAL))
    sims = single[-9:] @ single[-9:].T
    print(model, "somiglianze tra le 9 frasi a tema (3 argomenti x 3):")
    print(np.round(sims, 2))
    out[model] = [{"text": t, "vec": [round(float(x), 7) for x in v]} for t, v in zip(texts, single)]

with open(f"{models}/embedding-reference.json", "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False)
print("ok")
