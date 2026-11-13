import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave local: android/key.properties. No CI, os secrets chegam por variáveis de ambiente.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) keystorePropertiesFile.inputStream().use { load(it) }
}
val ciKeystorePath = System.getenv("ANDROID_UPLOAD_KEYSTORE")?.takeIf { it.isNotBlank() }
val hasReleaseSigning = ciKeystorePath != null || keystorePropertiesFile.exists()

android {
    namespace = "com.venexus.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.venexus.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = if (ciKeystorePath != null) requireNotNull(System.getenv("ANDROID_KEY_ALIAS")) else keystoreProperties.getProperty("keyAlias")
                keyPassword = if (ciKeystorePath != null) requireNotNull(System.getenv("ANDROID_KEY_PASSWORD")) else keystoreProperties.getProperty("keyPassword")
                storeFile = file(ciKeystorePath ?: keystoreProperties.getProperty("storeFile"))
                storePassword = if (ciKeystorePath != null) requireNotNull(System.getenv("ANDROID_KEYSTORE_PASSWORD")) else keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (System.getenv("PLAY_STORE_BUILD") == "true" && ciKeystorePath == null) {
                error("Build da Play Store exige ANDROID_UPLOAD_KEYSTORE.")
            }
            // Fora do workflow de publicação, a chave debug permite `flutter run --release` local.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Exigido pelo flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
