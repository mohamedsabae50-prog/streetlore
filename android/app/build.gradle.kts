plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
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
            // v1.0.73: keystore + passwords now sourced from
            //   - a release_v2.keystore file written by release.yml
            //     from the STREETLORE_KEYSTORE_BASE64 secret
            //   - the STREETLORE_KEYSTORE_PASSWORD + STREETLORE_KEY_PASSWORD
            //     secrets (fall back to the in-tree literals for local dev)
            // The release workflow writes the keystore from a base64
            // secret BEFORE this file is loaded, so on CI we always
            // have a non-empty file. Local debug builds still work
            // because the literal fallback matches a checked-in dev
            // keystore if present.
            storeFile = file("release_v2.keystore")
            storePassword =
                System.getenv("STREETLORE_KEYSTORE_PASSWORD") ?: "streetlore2026"
            keyAlias = "streetlore"
            keyPassword =
                System.getenv("STREETLORE_KEY_PASSWORD") ?: "streetlore2026"
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