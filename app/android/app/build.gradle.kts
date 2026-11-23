plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.chaquo.python")
    id("dev.flutter.flutter-gradle-plugin")
}

val privateSigningStorePath = System.getenv("AI_COMPANION_KEYSTORE_PATH")
val privateSigningStorePassword = System.getenv("AI_COMPANION_KEYSTORE_PASSWORD")
val privateSigningKeyAlias = System.getenv("AI_COMPANION_KEY_ALIAS")
val privateSigningKeyPassword = System.getenv("AI_COMPANION_KEY_PASSWORD")
val skipGenieNativeBuild = providers.gradleProperty("skipGenieNativeBuild")
    .map(String::toBoolean)
    .orElse(false)
    .get()
val privateSigningAvailable =
    !privateSigningStorePath.isNullOrBlank() &&
        !privateSigningStorePassword.isNullOrBlank() &&
        !privateSigningKeyAlias.isNullOrBlank() &&
        !privateSigningKeyPassword.isNullOrBlank()

android {
    namespace = "com.aicompanion.localfirst"
    compileSdk = flutter.compileSdkVersion
    // Match the user-verified standalone Genie v0.6.4 toolchain exactly.
    ndkVersion = "27.2.12479018"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets.getByName("main") {
        val ar = project.file("generated/whale-ar")
        java.srcDir(ar.resolve("java"))
        aidl.srcDir(ar.resolve("aidl"))
        res.srcDir(ar.resolve("res"))
        assets.srcDir(ar.resolve("assets"))
        jniLibs.srcDir(ar.resolve("jniLibs"))
        val privateAr = project.file("generated/whale-private")
        assets.srcDir(privateAr.resolve("assets"))
        jniLibs.srcDir(privateAr.resolve("jniLibs"))
    }
    androidResources { noCompress += "task" }

    buildFeatures {
        aidl = true
    }

    defaultConfig {
        applicationId = "com.aicompanion.localfirst"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // The Flutter Gradle plugin seeds its default ABI set before this
            // block. Appending arm64 leaves armeabi-v7a/x86_64 active, which
            // asks CMake to link OpenJTalk binaries that do not exist.
            abiFilters.clear()
            abiFilters += "arm64-v8a"
        }
        if (!skipGenieNativeBuild) {
            externalNativeBuild {
                cmake {
                    cppFlags += "-std=c++17"
                }
            }
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
            // The validated standalone Genie APK runs its ONNX Java/JNI bridge
            // without R8/resource shrinking. Preserve that release shape here.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    if (!skipGenieNativeBuild) {
        externalNativeBuild {
            cmake {
                path = file("src/main/cpp/CMakeLists.txt")
                version = "3.22.1"
            }
        }
    }

    packaging {
        // OpenJTalk is linked into the small JNI adapter as a real shared file.
        // Legacy packaging keeps the pinned arm64 library extractable on every
        // supported Android version.
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(files("generated/whale-private/runtime.jar"))
    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("androidx.camera:camera-lifecycle:1.4.2")
    implementation("com.google.ar:core:1.53.0")
    implementation("com.google.mediapipe:tasks-vision:0.10.32")
    implementation("androidx.core:core:1.15.0")
    implementation(files("libs/Live2DCubismCore.aar"))
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.22.0")
    // Offline PCM pitch adjustment for QQ files; no player or codec service.
    implementation("androidx.media3:media3-common:1.8.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
    testImplementation("org.robolectric:robolectric:4.14.1")
}

chaquopy {
    defaultConfig { version = "3.11" }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        check(file("generated/whale-ar/assets/hand_landmarker.task").isFile &&
              file("generated/whale-private/runtime.jar").isFile &&
              file("generated/whale-private/assets/easyar-license.txt").isFile) {
            "Prepare embedded AR with app/tools/whale_ar/prepare.sh and restore-private.sh"
        }
    }
}
