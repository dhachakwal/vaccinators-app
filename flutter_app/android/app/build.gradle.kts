import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: a REAL keystore from key.properties (CI decodes the
// KEYSTORE_BASE64 secret into android/app/upload-keystore.jks).
// NEVER commit the keystore or key.properties to the repo — the backup
// lives in the goal's hidden_files/keystore-backup/ + GitHub Secrets.
// LESSON (20 Nov 2026): release builds used debug signing, and GitHub
// runners generate a FRESH debug keystore on every run, so v1.0.0 and
// v1.0.1 had DIFFERENT signatures and Android refused the in-place
// update ("package conflicts with an existing package"). From v1.0.2
// every build signs with this one keystore, so in-app updates work.
// Local builds without key.properties fall back to debug signing.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.epi.chakwal.vaccinators_app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.epi.chakwal.vaccinators_app"
        // Version: keep in step with pubspec.yaml (1.0.2+3).
        // Bump BOTH files together on every release.
        minSdk = 21
        targetSdk = 34
        versionCode = 6
        versionName = "1.0.5"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signed with the real release keystore when key.properties
            // exists (CI); debug signing only for local builds.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
