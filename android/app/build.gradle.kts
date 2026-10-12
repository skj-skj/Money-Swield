plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.skj.expense.tracker.my_expense_tracker_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.skj.expense.tracker.my_expense_tracker_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 10: pictures the user saves go to Pictures/<AppName>
        // through MediaStore without a storage permission; the app's own
        // photos stay in its own folder (phase-6.md P6-1, P6-46).
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // foss: no closed-source code, what F-Droid builds (`gradle: [foss]`)
    // and the FOSS APK on GitHub. play: Google Play's AAB and a second APK
    // (phase-9a.md §6.6). Each its own applicationId, `.foss` / `.play`
    // after the base one (owner, 2026-10-11; P9a-23): the two install side
    // by side, each with its own data. The namespace (the Kotlin package)
    // stays the base one.
    flavorDimensions += "store"
    productFlavors {
        // The launcher name: foss says so, so the two can be told apart
        // when both are installed (owner, 2026-10-11).
        create("foss") {
            dimension = "store"
            applicationIdSuffix = ".foss"
            manifestPlaceholders["appLabel"] = "Expense Tracker (FOSS)"
        }
        create("play") {
            dimension = "store"
            applicationIdSuffix = ".play"
            manifestPlaceholders["appLabel"] = "Expense Tracker"
            // ML Kit's components are found by reflection; R8 needs to be
            // told to keep them (phase-9b.md §12a).
            proguardFiles("proguard-play.pro")
        }
    }

    // `-PnoSms=true` builds play without READ_SMS (D11, P9a-25): its
    // manifest is swapped for one that doesn't ask for it, and Dart reads
    // the merged manifest (SmsChannel `status.built`), so the feature hides.
    if (project.findProperty("noSms") == "true") {
        sourceSets.getByName("play").manifest.srcFile("src/playNoSms/AndroidManifest.xml")
    }

    // AGP adds Google's encrypted "dependency metadata" block to APKs;
    // F-Droid's build refuses it ("found extra signing block", phase-9a.md
    // F8). Play reads it from the AAB, so it stays there (P9a-33).
    dependenciesInfo {
        includeInApk = false
        includeInBundle = true
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
    // On-device AI for SMS (phase-9b.md §6.1): closed source, so play only
    // (P9b-2). F-Droid builds `gradle: [foss]` and its scanner never reads
    // a `playImplementation` line (phase-9b.md F7). Quoted: the Kotlin DSL
    // has no generated accessor for a flavor's configuration.
    "playImplementation"("com.google.mlkit:genai-prompt:1.0.0-beta4")
}
