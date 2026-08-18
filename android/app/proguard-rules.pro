# ONNX Runtime's native JNI layer resolves these Java classes and methods by
# their original names. R8 renaming them makes Android 16 abort the process in
# GetMethodID instead of returning a recoverable inference error.
-keep class ai.onnxruntime.** { *; }
-keep interface ai.onnxruntime.** { *; }
-keepattributes Signature,InnerClasses,EnclosingMethod
