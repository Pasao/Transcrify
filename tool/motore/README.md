# Riferimenti per i test del motore

I test in `android/app/src/test/.../engine` confrontano il nostro tokenizer e il nostro OnnxEmbedder
con le librerie ufficiali (Hugging Face `tokenizers` e `onnxruntime` in Python). Questi script
rifanno i riferimenti; i modelli non stanno nel repo.

```sh
python -m venv venv && venv/Scripts/pip install tokenizers onnxruntime numpy
# i modelli come li scarica l'app: <cartella>/preciso/{model_q4.onnx, model_q4.onnx_data, tokenizer.json}
#                                   <cartella>/leggero/{model_quantized.onnx, tokenizer.json}
venv/Scripts/python tool/motore/make_token_refs.py <cartella> android/app/src/test/resources/tokenizer-reference.json <cartella>/tokenizer-reference-extra.json
venv/Scripts/python tool/motore/make_vec_refs.py <cartella>   # scrive <cartella>/embedding-reference.json
```

Poi i test, con `TRANSCRIFY_MODELS=<cartella>` (e su Windows `TRANSCRIFY_TEST_JAVA`, vedi `TestModels.kt`).
