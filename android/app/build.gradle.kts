import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.skj.money.swield.expense.tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The flavor and build type add `.foss` / `.play` and `.debug` (see
        // below).
        applicationId = "com.skj.money.swield.expense.tracker"
        // You can update the following values to match your application needs.
        // For more information, see:
        // https://flutter.dev/to/review-gradle-config. Android 10: pictures the
        // user saves go to Pictures/<AppName> through MediaStore without a
        // storage permission; the app's own photos stay in its own folder.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The upload / release key, read from android/key.properties (never
    // committed). Without that file, release builds are signed with the
    // debug key so `flutter run --release` and F-Droid's build (which signs
    // with its own key) still work; `make bundle` and `make github` refuse
    // to run without it.
    val keyProperties = Properties()
    val keyPropertiesFile = rootProject.file("key.properties")
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { keyProperties.load(it) }
    }
    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // A debug build is its own app, `<id>.debug`, so installing one
        // never touches the data of the released app on the same phone
        // (owner, 2026-10-12).
        debug {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["labelSuffix"] = " (debug)"
        }
        // Flutter's plugin creates `profile` as a copy of `debug` before this
        // block runs, so it gets none of the above: without these it would
        // fail the manifest merge and take the released app's id.
        getByName("profile") {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["labelSuffix"] = " (profile)"
        }
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            manifestPlaceholders["labelSuffix"] = ""
        }
    }

    // foss: no closed-source code, what F-Droid builds (`gradle: [foss]`) and
    // the FOSS APKs on GitHub. play: Google Play's AAB and the play APKs on
    // GitHub. Each its own applicationId, `.foss` / `.play` after the base
    // one (owner, 2026-10-11): the two install side by side, each with its
    // own data. The namespace (the Kotlin package) stays the base one.
    flavorDimensions += "store"
    productFlavors {
        // The launcher name: foss says so, so the two can be told apart
        // when both are installed (owner, 2026-10-11).
        create("foss") {
            dimension = "store"
            applicationIdSuffix = ".foss"
            manifestPlaceholders["appLabel"] = "Money Swield (FOSS)"
        }
        create("play") {
            dimension = "store"
            applicationIdSuffix = ".play"
            manifestPlaceholders["appLabel"] = "Money Swield"
            // ML Kit's components are found by reflection; R8 needs to be told
            // to keep them.
            proguardFiles("proguard-play.pro")
        }
    }

    // `-PnoSms=true` builds play without READ_SMS: its manifest is swapped for
    // one that doesn't ask for it, and Dart reads the merged manifest
    // (SmsChannel `status.built`), so the feature hides.
    if (project.findProperty("noSms") == "true") {
        sourceSets.getByName("play").manifest.srcFile("src/playNoSms/AndroidManifest.xml")
    }

    // AGP adds Google's encrypted "dependency metadata" block to APKs;
    // F-Droid's build refuses it ("found extra signing block"). Play reads it
    // from the AAB, so it stays there.
    dependenciesInfo {
        includeInApk = false
        includeInBundle = true
    }

    // Native libraries (libflutter.so, libapp.so) compressed in APKs: the
    // GitHub / F-Droid download halves (arm64 ~20 MB to ~9 MB), at the cost
    // of Android unpacking them once at install (~10 MB more on the phone,
    // same speed once running). The AAB keeps them stored uncompressed: Play
    // compresses its downloads anyway, so there it would only cost storage
    // (owner, 2026-10-14). Flutter runs Gradle with `bundle<Flavor><Type>`
    // for an AAB and `assemble…` for an APK.
    val buildingBundle = gradle.startParameter.taskNames.any {
        it.substringAfterLast(':').startsWith("bundle")
    }
    packaging {
        jniLibs {
            useLegacyPackaging = !buildingBundle
        }
        // Kotlin's reflection metadata and coroutine debug-probe files: read
        // only by kotlin-reflect and debuggers, neither of which the app uses.
        resources {
            excludes += listOf(
                "kotlin/**",
                "kotlin-tooling-metadata.json",
                "DebugProbesKt.bin",
                "META-INF/*.version",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // JVM unit tests of the channels' plain Kotlin (`make test-android`).
    testImplementation("junit:junit:4.13.2")
    // On-device AI for SMS: closed source, so play only. F-Droid builds
    // `gradle: [foss]` and its scanner never reads a `playImplementation` line.
    // Quoted: the Kotlin DSL has no generated accessor for a flavor's
    // configuration.
    "playImplementation"("com.google.mlkit:genai-prompt:1.0.0-beta4")
}
