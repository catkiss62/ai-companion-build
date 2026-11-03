plugins {
    id("com.android.library") version "8.9.1"
    id("org.jetbrains.kotlin.android") version "2.1.0"
}
val syncProductionSources = tasks.register<Sync>("syncProductionSources") {
    from("../../android/app/src/main/kotlin/com/aicompanion/localfirst") {
        include("VoiceExportPcmTuning.kt", "VoiceExportOwnership.kt")
    }
    into(layout.buildDirectory.dir("generated/production-sources"))
}
val syncProductionTests = tasks.register<Sync>("syncProductionTests") {
    from("../../android/app/src/test/kotlin/com/aicompanion/localfirst") {
        include("VoiceExportPcmTuningTest.kt", "VoiceExportOwnershipTest.kt")
    }
    into(layout.buildDirectory.dir("generated/production-tests"))
}
android {
    namespace = "com.aicompanion.voiceexporttests"
    compileSdk = 35
    defaultConfig { minSdk = 24 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    sourceSets.getByName("main").java.srcDir(layout.buildDirectory.dir("generated/production-sources"))
    // Kotlin source discovery does not honor Java include filters on a shared
    // directory. Sync the two original test files into their own source root.
    sourceSets.getByName("test").java.srcDir(layout.buildDirectory.dir("generated/production-tests"))
}
tasks.named("preBuild").configure { dependsOn(syncProductionSources, syncProductionTests) }
dependencies {
    implementation("androidx.media3:media3-common:1.8.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
}
