pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // [FIX 1] Changed from 'flutter-plugin-loader' to 'flutter-gradle-plugin'
    // This matches what is applied in app/build.gradle.kts
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false

    // [FIX 2] Use a standard stable AGP version (8.11.1 is fine if you have latest Studio)
    id("com.android.application") version "8.2.1" apply false

    // [FIX 3] Downgraded Kotlin to 1.9.24 (Stable standard for Flutter)
    // 2.2.20 is likely causing the task generation conflict
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

include(":app")