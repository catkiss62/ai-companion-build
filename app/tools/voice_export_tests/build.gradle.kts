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
    sourceSets.getByName("test").java.apply {
        srcDir("../../android/app/src/test/kotlin")
        include("com/aicompanion/localfirst/VoiceExportPcmTuningTest.kt")
        include("com/aicompanion/localfirst/VoiceExportOwnershipTest.kt")
    }
}
tasks.named("preBuild").configure { dependsOn(syncProductionSources) }
dependencies {
    implementation("androidx.media3:media3-common:1.8.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
}
