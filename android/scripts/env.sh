# Shared settings for the Android scripts. Source it: `. android/scripts/env.sh`.
# Toolchain (2026-11-13): swift.org Swift 6.4.2 (not Xcode's), the Swift SDK for Android 6.4.2, NDK r30.
#   Toolchain: https://download.swift.org/swift-6.4.2-release/xcode/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE-osx.pkg
#              installer -pkg <pkg> -target CurrentUserHomeDirectory
#   SDK:       swift sdk install https://download.swift.org/swift-6.4.2-release/android-sdk/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE_android.artifactbundle.tar.gz \
#                --checksum 4d6ad63ea74becd58e123ff58b1b48c3be5ec0db0dff0ea5abe37ac007dd3233
#   NDK:       https://dl.google.com/android/repository/android-ndk-r30-darwin.zip → ~/Library/Android/sdk/ndk/android-ndk-r30
#              ANDROID_NDK_HOME=... ~/Library/org.swift.swiftpm/swift-sdks/swift-6.4.2-RELEASE_android.artifactbundle/swift-android/scripts/setup-android-sdk.sh
export SWIFT_TC="${SWIFT_TC:-$HOME/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain/usr/bin}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/android-ndk-r30}"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
export SWIFT_ANDROID_TRIPLE=aarch64-unknown-linux-android33
export SWIFT_ANDROID_SDK="$HOME/Library/org.swift.swiftpm/swift-sdks/swift-6.4.2-RELEASE_android.artifactbundle/swift-android"
export SWIFT_ANDROID_LIBS="$SWIFT_ANDROID_SDK/swift-resources/usr/lib/swift-aarch64/android"
export NDK_LIBCXX="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"
