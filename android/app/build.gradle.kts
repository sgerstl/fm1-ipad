plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21) } }

android {
    namespace = "com.scottgerstl.lupe"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.scottgerstl.lupe"
        minSdk = 33
        targetSdk = 36
        versionCode = 2
        versionName = "0.2"
    }

    buildTypes {
        release { isMinifyEnabled = false }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
    buildFeatures { compose = true }

    // The fixtures live outside app/ so the Swift side (P1) writes to the same folder: assets/state/*.json
    sourceSets.getByName("main").assets.srcDir("../fixtures")

    // P1: libLupeNative.so and the Swift runtime it needs, built by android/scripts/build-native.sh (BRIDGE.md §3).
    sourceSets.getByName("main").jniLibs.srcDir(layout.buildDirectory.dir("swift/jniLibs"))
    defaultConfig { ndk { abiFilters += "arm64-v8a" } }   // the Pixel 10 Pro; the Swift build is arm64 only
    // Audio through (AAudio, C++): libLupeThrough.so, built by android/scripts/build-through.sh (app/src/main/cpp/through)
    sourceSets.getByName("main").jniLibs.srcDir(layout.buildDirectory.dir("through/jniLibs"))
    // Debug only: SloopKit's FakeSkiff fixtures for the demo core (prefs core = "demo"; the emulator has no FM-1). The APK has
    // no SwiftPM resource bundle, so they ride as assets/demo/*.json and LupeStartup copies them into the app's files.
    sourceSets.getByName("debug").assets.srcDir(layout.buildDirectory.dir("demoAssets"))
}

val demoFixtures by tasks.registering(Copy::class) {
    from(rootProject.file("../ios/SloopKit/Sources/SloopKit/Resources")) { include("*.json") }
    into(layout.buildDirectory.dir("demoAssets/demo"))
}
tasks.matching { it.name == "mergeDebugAssets" || it.name == "generateDebugAssets" }.configureEach { dependsOn(demoFixtures) }

// The native code's build: debug unless `-PnativeConfig=release` (the public APK: Swift in release mode, stripped).
val nativeConfig = (findProperty("nativeConfig") as String?) ?: "debug"

// P1: builds the Swift core before Gradle packs native libraries. Swift's own build is incremental.
val buildSwift by tasks.registering(Exec::class) {
    description = "Builds android/core (LupeNative) for arm64 Android"
    val out = layout.buildDirectory.dir("swift/jniLibs").get().asFile
    commandLine(rootProject.file("scripts/build-native.sh").path, out.path, nativeConfig)
    outputs.dir(out)
    outputs.upToDateWhen { false }
}
// Audio through: the AAudio engine, one C++ file and its header, compiled with the NDK's clang (no CMake needed)
val buildThrough by tasks.registering(Exec::class) {
    description = "Builds app/src/main/cpp/through (libLupeThrough.so) for arm64 Android"
    val out = layout.buildDirectory.dir("through/jniLibs").get().asFile
    commandLine(rootProject.file("scripts/build-through.sh").path, out.path, nativeConfig)
    inputs.dir(file("src/main/cpp/through"))
    outputs.dir(out)
}
tasks.matching { it.name.startsWith("merge") && it.name.endsWith("JniLibFolders") }.configureEach { dependsOn(buildSwift, buildThrough) }

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.09.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
}
