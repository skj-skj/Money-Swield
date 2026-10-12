# R8 rules for the play flavor only (phase-9b.md §12a).
#
# ML Kit finds its components by reflection: Firebase's ComponentDiscovery
# reads `com.google.firebase.components:<class>` from the merged manifest and
# calls the class's no-argument constructor. R8 can't see that call and
# dropped the constructor of com.google.mlkit.common.internal
# .CommonComponentRegistrar ("NoSuchMethodException ... <init> []"), so a
# release build's first ML Kit call threw and the app crashed (found on the
# Pixel 11 Pro, 2026-10-12; ML Kit GenAI 1.0.0-beta4 ships no rule for it).
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    <init>();
}
