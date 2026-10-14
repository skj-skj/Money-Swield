// Gradle init script for `make check-dep`: adds the Gradle Versions Plugin
// (open source, github.com/ben-manes/gradle-versions-plugin) only for that
// run, so the app's build files, and the F-Droid build, never load it.
// `./gradlew -I <this file> dependencyUpdates` then reports the Gradle
// wrapper, the plugins and the Kotlin libraries that have newer versions.
//
// Pinned instead of `+`, so a new plugin release can't change the report
// without a change here.
//
// Pre-release candidates are shown only for dependencies already on a
// pre-release (see `rejectVersionIf` below).
//
// Expected in the report: `io.flutter:*` engine artifacts under "Failed to
// determine" (they come with the Flutter SDK, not from a Maven repository),
// and `com.android.tools.build:gradle` at the version the Flutter Gradle
// plugin builds with. Both change with `flutter upgrade`, not here.

import com.github.benmanes.gradle.versions.VersionsPlugin
import com.github.benmanes.gradle.versions.updates.DependencyUpdatesTask

initscript {
    repositories {
        gradlePluginPortal()
    }

    dependencies {
        classpath("io.github.ben-manes:gradle-versions-plugin:0.66.0")
    }
}

apply<VersionsPlugin>()

// Tools the Android and Kotlin plugins add for themselves (test platform,
// lint, JaCoCo, compiler classpaths): their versions follow the plugin,
// which is reported itself. These are the plugins' internal names, so a
// rename in an AGP or Kotlin release brings a tool back into the report
// without any error; add its new configuration name here when that happens.
val pluginInternalConfigurations =
    setOf(
        "androidLintTool",
        "androidJacocoAnt",
        "kotlinCompilerClasspath",
        "kotlinBuildToolsApiClasspath",
        "kotlinAbiValidationCompatClasspath",
        "kotlinKlibCommonizerClasspath",
        "kotlinBouncyCastleConfiguration",
    )

// Alpha, beta, RC, milestone, EAP and dev builds.
val unstableVersion = Regex("""(?i).*[.-](alpha|beta|rc|m|eap|dev)[.-]?\d*.*""")

gradle.rootProject(
    Action<Project> {
        tasks.withType(DependencyUpdatesTask::class.java).configureEach {
            filterDeclaredConfigurations =
                Spec<String> { name ->
                    name !in pluginInternalConfigurations &&
                        !name.contains("unified-test-platform-") &&
                        !(
                            name.startsWith("kotlinCompilerPluginClasspath") &&
                                name != "kotlinCompilerPluginClasspath"
                        )
                }

            // A stable dependency is offered stable releases only, so the
            // report isn't filled with alphas and betas. A dependency already
            // on a pre-release (such as ML Kit GenAI Prompt, which has no
            // stable release yet) is still offered newer pre-releases, to keep
            // it up to date.
            rejectVersionIf {
                unstableVersion.matches(candidate.version) &&
                    !unstableVersion.matches(currentVersion)
            }
        }
    },
)
