plugins {
    id("com.android.application") version "8.9.1"
    id("org.jetbrains.kotlin.android") version "2.1.0"
}

val syncImportSources = tasks.register<Sync>("syncImportSources") {
    from("../../android/app/src/main/kotlin/com/catkiss/senlive2dcompanion") {
        include("CaicaiModelRepository.kt", "CaicaiModelPaths.kt", "CaicaiDiagnostics.kt")
    }
    into(layout.buildDirectory.dir("generated/import-sources"))
}

android {
    namespace = "com.catkiss.senlive2dcompanion.smoke"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.catkiss.senlive2dcompanion.smoke"
        minSdk = 26
        targetSdk = 35
        versionCode = 285
        versionName = "0.42.41"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk { abiFilters += "x86_64" }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    sourceSets.getByName("main") {
        // Compile the actual production renderer, import repository and diagnostics.
        // No copied host implementation, private model, Flutter or TTS payload.
        java.srcDirs("../../android/app/src/main/java", layout.buildDirectory.dir("generated/import-sources"))
        java.exclude("io/flutter/**")
    }
}
tasks.named("preBuild").configure { dependsOn(syncImportSources) }

dependencies {
    implementation(files("../../android/app/libs/Live2DCubismCore.aar"))
    androidTestImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
