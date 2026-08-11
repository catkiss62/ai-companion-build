plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aicompanion.localfirst"
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
        applicationId = "com.aicompanion.localfirst"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += setOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // Prototype: replace with a private release keystore before distributing broadly.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        // The compatibility DexClassLoader resolves native libraries from the
        // installed nativeLibraryDir. Legacy packaging guarantees real files
        // exist there instead of relying only on APK-in-place loading.
        jniLibs {
            useLegacyPackaging = true
            // Keep the user-validated Meju native payload byte-identical in
            // release APKs. AGP otherwise strips libbertvits2.so, which changes
            // its golden SHA-256 before installation.
            keepDebugSymbols += setOf(
                "**/libbertvits2.so",
                "**/libMNN.so",
                "**/libMNN_Express.so",
                "**/libMNN_Vulkan.so",
                "**/libcppjieba.so",
                "**/libcpptokenizer.so",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.gms:play-services-nearby:19.3.0")
}
