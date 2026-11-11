# Flutter Wrapper Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# LEVELS Application Classes
-keep class com.watermon.water_tank_monitor.** { *; }

# Keep annotations and native methods
-keepattributes *Annotation*
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep serializable and parcelable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# AndroidX / Support library rules
-dontwarn io.flutter.embedding.**
-dontwarn androidx.**
