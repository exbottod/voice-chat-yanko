-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Kelas desugar yang tidak ikut terbawa, hanya dipakai saat build lama.
-dontwarn com.google.devtools.build.android.desugar.runtime.ThrowableExtension
