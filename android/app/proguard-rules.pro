# Preserve metadata used by Flutter plugins and native JSON libraries.
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Flutter registers plugins by generated entry point and uses JNI for engine
# callbacks. The Flutter Gradle plugin also supplies its own baseline rules.
-keep class io.flutter.embedding.engine.FlutterJNI { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Geolocator plugin entry points may be resolved from Flutter's plugin
# registry; keep the plugin while allowing R8 to optimize unrelated packages.
-keep class com.baseflow.geolocator.** { *; }

# Keep only Play Services APIs used by Google Sign-In, Maps/location plugins,
# and asynchronous task callbacks rather than the entire Play Services SDK.
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep @com.google.android.gms.common.annotation.KeepForSdk class * { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Supabase's Flutter client is Dart-based, but retain its native bridge if
# supplied by a plugin or added as an Android dependency.
-keep class io.supabase.** { *; }
-keep class io.gotrue.** { *; }

# Retain serialized field names for optional native Gson/Moshi/Kotlin models;
# Dart JSON serialization is compiled into Flutter's AOT snapshot.
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
    @com.squareup.moshi.Json <fields>;
    @kotlinx.serialization.SerialName <fields>;
}
-keep @com.squareup.moshi.JsonClass class * { *; }
-keep class **$$serializer { *; }

# Keep line-numbered stack traces while removing debug logging in release.
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
}
