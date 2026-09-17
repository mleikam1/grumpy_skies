import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Only DayMaker-specific metadata may replace this official demo app ID.
val daymakerAdMobAppId = providers.gradleProperty("daymakerAdMobAppId")
    .getOrElse("ca-app-pub-3940256099942544~3347511713")
val daymakerDartDefines = providers.gradleProperty("dart-defines").getOrElse("")
val daymakerReleaseBuild = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val validateDaymakerAds by tasks.registering(Exec::class) {
    commandLine("python3", "../../tools/validate_monetization.py", "--platform", "android",
        "--mode", if (daymakerReleaseBuild) "release" else "debug",
        "--defines", daymakerDartDefines, "--app-id", daymakerAdMobAppId)
}
tasks.matching { it.name == "preBuild" }.configureEach { dependsOn(validateDaymakerAds) }

android {
    namespace = "com.example.grumpy_skies"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.grumpy_skies"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        manifestPlaceholders["daymakerAdMobAppId"] = daymakerAdMobAppId
        targetSdk = flutter.targetSdkVersion
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
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}
