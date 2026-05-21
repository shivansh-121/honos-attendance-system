# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Play Store Deferred Components (not used but referenced)
-dontwarn com.google.android.play.core.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google ML Kit Face Detection
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }

# TFLite Flutter
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Camera
-keep class io.flutter.plugins.camera.** { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
