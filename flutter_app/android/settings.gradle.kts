pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = File(rootDir, "local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) {
            "flutter.sdk not set in local.properties"
        }
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
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.3.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

// WHY THIS EXISTS: geolocator_android 4.6.2 still reads the legacy
// `flutter.*` Gradle properties (flutter.compileSdkVersion /
// flutter.minSdkVersion) in its own build.gradle, but Flutter's
// current Gradle plugin only defines those on the app project —
// so that plugin project fails to evaluate. Give them to that
// ONE project only, before its build script runs. (Do NOT define
// them globally with ext.flutter in a root build.gradle: that
// shadows the app project's own `flutter` extension and breaks
// the Flutter Gradle plugin with "Must provide Flutter source
// directory".)
gradle.beforeProject {
    if (name == "geolocator_android") {
        extensions.extraProperties["flutter"] = mapOf(
            "compileSdkVersion" to 34,
            "minSdkVersion" to 21,
            "targetSdkVersion" to 34
        )
    }
}

include(":app")
