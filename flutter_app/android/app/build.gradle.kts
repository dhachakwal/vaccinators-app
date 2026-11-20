plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.epi.chakwal.vaccinators_app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.epi.chakwal.vaccinators_app"
        // Version: keep in step with pubspec.yaml (1.0.0+1).
        // Bump BOTH files together on every release.
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            // Debug signing is used by the free GitHub Actions build.
            // A release keystore is NOT needed for sideloading from
            // the EPI site (no Play Store). Add signingConfigs only
            // if the app ever goes to the Play Store.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}
