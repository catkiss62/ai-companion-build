plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val privateSigningStorePath = System.getenv("AI_COMPANION_KEYSTORE_PATH")
val privateSigningStorePassword = System.getenv("AI_COMPANION_KEYSTORE_PASSWORD")
val privateSigningKeyAlias = System.getenv("AI_COMPANION_KEY_ALIAS")
val privateSigningKeyPassword = System.getenv("AI_COMPANION_KEY_PASSWORD")
val privateSigningAvailable =
    !privateSigningStorePath.isNullOrBlank() &&
        !privateSigningStorePassword.isNullOrBlank() &&
        !privateSigningKeyAlias.isNullOrBlank() &&
        !privateSigningKeyPassword.isNullOrBlank()

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

    signingConfigs {
        if (privateSigningAvailable) {
            create("privateStableTest") {
                storeFile = file(privateSigningStorePath!!)
                storePassword = privateSigningStorePassword
                keyAlias = privateSigningKeyAlias
                keyPassword = privateSigningKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // CI uses one persistent private test identity. Local builds keep the
            // debug fallback so contributors do not need the private keystore.
            signingConfig = if (privateSigningAvailable) {
                signingConfigs.getByName("privateStableTest")
            } else {
                signingConfigs.getByName("debug")
            }
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
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
}
