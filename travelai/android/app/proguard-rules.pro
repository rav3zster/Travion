# ProGuard rules to fix R8 missing class error for Mappls SDK
-dontwarn com.ryanharter.auto.value.gson.GsonTypeAdapterFactory

# TensorFlow Lite keep rules
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**
