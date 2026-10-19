import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localSigningProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.isFile) {
        propertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.streetlore.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // تم إضافة السطر ده هنا
    }

    defaultConfig {
        applicationId = "com.alsaba.egyptlore"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file(
                localSigningProperties.getProperty("storeFile") ?: "release_v2.keystore",
            )
            storePassword = providers.gradleProperty("STREETLORE_KEYSTORE_PASSWORD")
                .orElse(providers.environmentVariable("STREETLORE_KEYSTORE_PASSWORD"))
                .orNull
                ?: localSigningProperties.getProperty("storePassword")
                ?: ""
            keyAlias = localSigningProperties.getProperty("keyAlias") ?: "streetlore"
            keyPassword = providers.gradleProperty("STREETLORE_KEY_PASSWORD")
                .orElse(providers.environmentVariable("STREETLORE_KEY_PASSWORD"))
                .orNull
                ?: localSigningProperties.getProperty("keyPassword")
                ?: localSigningProperties.getProperty("storePassword")
                ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.core:core-ktx:1.16.0")
}