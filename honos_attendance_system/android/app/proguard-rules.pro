# Flutter core
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Flutter Play Store Deferred Components (not used but referenced by Flutter engine)
-dontwarn com.google.android.play.core.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google ML Kit Face Detection - keep ALL classes
-keep class com.google.mlkit.** { *; }
-keepclassmembers class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-keep class com.google.mlkit.vision.** { *; }
-keep class com.google.mlkit.vision.face.** { *; }

# TFLite Flutter - CRITICAL: keep all native bindings
-keep class org.tensorflow.** { *; }
-keepclassmembers class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**
-keep class org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keepclassmembers class org.tensorflow.lite.gpu.** { *; }

# TFLite Flutter plugin JNI bridge - must not be stripped
-keep class com.tfliteflutter.** { *; }
-keepclassmembers class com.tfliteflutter.** { *; }
-dontwarn com.tfliteflutter.**

# Camera
-keep class io.flutter.plugins.camera.** { *; }
-keepclassmembers class io.flutter.plugins.camera.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Keep native methods - critical for JNI/TFLite
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions

# Keep enum classes intact
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
