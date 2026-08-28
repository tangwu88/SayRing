import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val veepooSdkArtifacts =
    listOf(
        "vpprotocol-2.3.77.15.aar",
        "vpbluetooth-1.20.aar",
        "abpartool-release.aar",
    )
val veepooSdkFiles = veepooSdkArtifacts.map { file("libs/$it") }
val hasAnyVeepooArtifact = veepooSdkFiles.any { it.isFile }
val hasCompleteVeepooSdk = veepooSdkFiles.all { it.isFile }
val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties().apply {
    if (signingPropertiesFile.isFile) {
        signingPropertiesFile.inputStream().use(::load)
    }
}

if (hasAnyVeepooArtifact && !hasCompleteVeepooSdk) {
    val missing = veepooSdkFiles.filterNot { it.isFile }.joinToString { it.name }
    throw GradleException("Veepoo SDK 文件不完整，缺少：$missing")
}

android {
    namespace = "cc.saidian.saydian_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "cc.saidian.app"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("boolean", "VEEPOO_SDK_PRESENT", hasCompleteVeepooSdk.toString())
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (signingPropertiesFile.isFile) {
            create("productionRelease") {
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
                storeFile = file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Local QA keeps the existing debug-signing fallback.  Tagged
            // online releases provide key.properties from GitHub Secrets and
            // therefore use the stable production key.
            signingConfig = signingConfigs.getByName(
                if (signingPropertiesFile.isFile) "productionRelease" else "debug",
            )
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.tencent.mm.opensdk:wechat-sdk-android:6.8.40")
    implementation("com.alipay.sdk:alipaysdk-android:15.8.42")
    if (hasCompleteVeepooSdk) {
        implementation(files(veepooSdkFiles))
        implementation("com.google.code.gson:gson:2.13.2")
        implementation("no.nordicsemi.android:mcumgr-core:2.7.4")
        implementation("no.nordicsemi.android:mcumgr-ble:2.7.4")
        implementation("no.nordicsemi.android.support.v18:scanner:1.4.2")
        implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
    }
}
