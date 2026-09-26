import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties().apply {
    rootProject.file("key.properties").inputStream().use { load(it) }
}

android {
    namespace = "com.catchingclouds.marsthoughts"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.catchingclouds.marsthoughts"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }

    buildTypes {
        debug {
            // "Mars Thoughts Debug" installs side by side with the release build.
            applicationIdSuffix = ".debug"
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // `store` is the Play Store app exactly as before. `personal` is the
    // private build with sync: its own applicationId so it installs next to
    // the store app, and the only variant whose manifest declares INTERNET
    // (see src/personal/AndroidManifest.xml). The Dart side keys off the same
    // flavor name (lib/sync/sync_flags.dart).
    flavorDimensions += "distribution"
    productFlavors {
        create("store") {
            dimension = "distribution"
        }
        create("personal") {
            dimension = "distribution"
            applicationIdSuffix = ".personal"
        }
    }
}

// One label per variant, built from flavor + build type, so the four
// installable combinations are told apart on the launcher. Placeholders
// merged from flavor *and* build type would otherwise overwrite each other.
androidComponents {
    onVariants { variant ->
        val label = buildString {
            append("Mars Thoughts")
            if (variant.flavorName == "personal") append(" Personal")
            if (variant.buildType == "debug") append(" Debug")
        }
        variant.manifestPlaceholders.put("appLabel", label)
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
