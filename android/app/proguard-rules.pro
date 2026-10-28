# ONNX Runtime: la parte nativa crea e legge oggetti Java per nome (OnnxTensor, OrtException,
# TensorInfo…). Se R8 li rinominasse o togliesse, il modello si pianterebbe solo nella build release.
-keep class ai.onnxruntime.** { *; }
