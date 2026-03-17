plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.cwnu_demo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    // AGP 8.x automatically propagates targetCompatibility to Kotlin jvmTarget;
    // using the deprecated String-typed kotlinOptions.jvmTarget causes a compile
    // error in Kotlin 2.2, so we set it via the compiler tasks instead.

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.cwnu_demo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
}

// ─── Rust (flutter_rust_bridge) ───────────────────────────────────────────────
// 在 preBuild 之前用 cargo-ndk 交叉编译 native/ crate，产出 .so 放入 jniLibs。
// 前置条件：
//   cargo install cargo-ndk
//   rustup target add aarch64-linux-android x86_64-linux-android
val rustLibName = "libget_time_2_rust.so"
val jniLibsDir = file("src/main/jniLibs")
tasks.register("buildRustLib") {
    group = "build"
    description = "使用 cargo-ndk 交叉编译 Rust native crate"
    doLast {
        exec {
            workingDir = file("../../native")
            commandLine(
                "cargo", "ndk",
                "-t", "arm64-v8a",
                "-t", "x86_64",
                "-o", jniLibsDir.canonicalPath,
                "build", "--lib", "--release",
            )
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn("buildRustLib")
}

