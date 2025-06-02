import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ✅ Kotlin-compatible way to read local.properties
fun getLocalProperty(key: String, file: String = "local.properties"): String {
    val properties = Properties()
    val propFile = rootProject.file(file)
    if (propFile.exists()) {
        properties.load(FileInputStream(propFile))
    }
    return properties.getProperty(key) ?: ""
}

val flutterVersionCode = getLocalProperty("flutter.versionCode").ifEmpty { "1" }
val flutterVersionName = getLocalProperty("flutter.versionName").ifEmpty { "1.0" }

android {
    namespace = "com.example.ai_duplicate_removal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.example.ai_duplicate_removal"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
