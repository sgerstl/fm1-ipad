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
        versionCode = 1
        versionName = "0.1-p2-shell"
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
}

// P1: builds the Swift core before Gradle packs native libraries. Swift's own build is incremental.
val buildSwift by tasks.registering(Exec::class) {
    description = "Builds android/core (LupeNative) for arm64 Android"
    val out = layout.buildDirectory.dir("swift/jniLibs").get().asFile
    commandLine(rootProject.file("scripts/build-native.sh").path, out.path, "debug")
    outputs.dir(out)
    outputs.upToDateWhen { false }
}
tasks.matching { it.name.startsWith("merge") && it.name.endsWith("JniLibFolders") }.configureEach { dependsOn(buildSwift) }

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
