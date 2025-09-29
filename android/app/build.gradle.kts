plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.murobird"

    // Puedes usar el que expone Flutter o poner 34 directamente.
    compileSdk = flutter.compileSdkVersion

    // NDK requerido por tus plugins
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.murobird"

        // ✅ tflite_flutter requiere al menos 26
        minSdk = 26

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // multiDexEnabled no es necesario con minSdk >= 21
    }

    // Recomendado con AGP/Flutter modernos: Java 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
