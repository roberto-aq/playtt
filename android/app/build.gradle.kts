import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clave de firma de la versión release. Se lee de android/key.properties, que
// NO se sube al repositorio (está en android/.gitignore). Cómo crearla:
// docs/development.md → "Compilación para publicar".
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.playtt.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Identificador permanente de la app en el teléfono y en Google Play.
        applicationId = "com.playtt.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Salen de "version:" en pubspec.yaml (nombre+código, p. ej. 1.0.0+1).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                // Sin key.properties se firma con la clave de depuración para
                // que el proyecto compile en cualquier PC. Ese APK NO sirve
                // para distribuir: no podría actualizarse con uno firmado.
                logger.warn("⚠ key.properties no encontrado: la versión release se firma con la clave de DEPURACIÓN.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider, para compartir audios con otras apps (MainActivity.shareFile).
    implementation("androidx.core:core:1.13.1")
}
