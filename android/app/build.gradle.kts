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
val coolWearSdkFile = file("libs/coolwear_bluesdk-release.aar")
val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties().apply {
    if (signingPropertiesFile.isFile) {
        signingPropertiesFile.inputStream().use(::load)
    }
}
val jpushAppKey =
    providers.gradleProperty("JPUSH_APPKEY")
        .orElse(providers.environmentVariable("JPUSH_APP_KEY"))
        .orNull
        ?.trim()
        .orEmpty()
val jpushChannel =
    providers.gradleProperty("JPUSH_CHANNEL")
        .orElse(providers.environmentVariable("JPUSH_CHANNEL"))
        .orNull
        ?.trim()
        .orEmpty()
val wechatAppId =
    providers.gradleProperty("WECHAT_APP_ID")
        .orElse(providers.environmentVariable("WECHAT_APP_ID"))
        .orElse("")
        .get()
        .trim()
fun releaseModeFlag(name: String): Boolean {
    val value = providers.environmentVariable(name).orNull?.trim()?.lowercase().orEmpty()
    return when (value) {
        "", "false" -> false
        "true" -> true
        else -> throw GradleException("$name must be true, false, or unset")
    }
}

val productionReleaseRequested = releaseModeFlag("SAIDIAN_PRODUCTION_RELEASE")
val qaReleaseAllowed = releaseModeFlag("SAIDIAN_ALLOW_QA_RELEASE")
// The production App supports physical ARM devices only.  Local Android
// emulators are x86_64, so permit that ABI only when the explicit Debug-only
// switch is supplied.  Release tasks below reject this switch.
val emulatorDebugRequested = releaseModeFlag("SAIDIAN_EMULATOR_DEBUG")
val debugEmulatorAbis = if (emulatorDebugRequested) setOf("x86_64") else emptySet()
val updateManifestUrl =
    providers.environmentVariable("SAYDIAN_UPDATE_MANIFEST_URL")
        .orNull
        ?.trim()
        .orEmpty()
val apiBaseUrl =
    providers.environmentVariable("SAYDIAN_API_BASE_URL")
        .orNull
        ?.trim()
        .orEmpty()
val updateAllowedHosts =
    providers.environmentVariable("SAYDIAN_UPDATE_ALLOWED_HOSTS")
        .orNull
        ?.trim()
        .orEmpty()
val jpushVendorChannels =
    providers.environmentVariable("JPUSH_VENDOR_CHANNELS")
        .orNull
        ?.trim()
        .orEmpty()
val enabledJpushVendorChannels =
    jpushVendorChannels
        .split(',')
        .map { it.trim().lowercase() }
        .filter(String::isNotEmpty)
        .toSet()
val huaweiPushEnabled = "huawei" in enabledJpushVendorChannels
if (huaweiPushEnabled) {
    val huaweiConfig = file("agconnect-services.json")
    if (!huaweiConfig.isFile) {
        throw GradleException(
            "Huawei push is enabled but android/app/agconnect-services.json is missing",
        )
    }
    apply(from = "huawei-agconnect.gradle")
}
val productionSigningValues =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .associateWith { signingProperties.getProperty(it)?.trim().orEmpty() }
val productionStoreFile =
    productionSigningValues.getValue("storeFile")
        .takeIf(String::isNotEmpty)
        ?.let(::file)
val hasCompleteProductionSigning =
    signingPropertiesFile.isFile &&
        productionSigningValues.values.all(String::isNotEmpty) &&
        productionStoreFile?.isFile == true

if (hasAnyVeepooArtifact && !hasCompleteVeepooSdk) {
    val missing = veepooSdkFiles.filterNot { it.isFile }.joinToString { it.name }
    throw GradleException("Veepoo SDK 文件不完整，缺少：$missing")
}
if (!coolWearSdkFile.isFile) {
    throw GradleException("CoolWear SDK 文件缺失：${coolWearSdkFile.name}")
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
        applicationId = "cn.saydian.ring"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Keep all distributable variants on the same two supported ARM ABIs.
        // A local emulator Debug run may opt into x86_64 through the explicit
        // switch above; the release gate separately checks ARM symmetry.
        ndk {
            abiFilters += setOf("armeabi-v7a", "arm64-v8a") + debugEmulatorAbis
        }
        manifestPlaceholders["JPUSH_APPKEY"] =
            jpushAppKey.ifEmpty { "debug-disabled" }
        manifestPlaceholders["JPUSH_CHANNEL"] =
            jpushChannel.ifEmpty { "developer-disabled" }
        buildConfigField("boolean", "VEEPOO_SDK_PRESENT", hasCompleteVeepooSdk.toString())
        buildConfigField("String", "WECHAT_APP_ID", "\"$wechatAppId\"")
    }

    buildFeatures {
        buildConfig = true
    }

    packaging {
        jniLibs {
            // Several transitive AARs also publish desktop/emulator binaries.
            // Distribution is intentionally limited to the two supported ARM
            // ABIs; release_gate.py verifies that their .so sets are symmetric.
            excludes +=
                buildSet {
                    add("lib/armeabi/**")
                    add("lib/x86/**")
                    if (!emulatorDebugRequested) {
                        add("lib/x86_64/**")
                    }
                }
        }
    }

    signingConfigs {
        if (hasCompleteProductionSigning) {
            create("productionRelease") {
                keyAlias = productionSigningValues.getValue("keyAlias")
                keyPassword = productionSigningValues.getValue("keyPassword")
                storeFile = productionStoreFile
                storePassword = productionSigningValues.getValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Local QA keeps the existing debug-signing fallback.  Tagged
            // online releases provide key.properties from GitHub Secrets and
            // therefore use the stable production key.
            signingConfig =
                if (productionReleaseRequested &&
                    !qaReleaseAllowed &&
                    hasCompleteProductionSigning
                ) {
                    signingConfigs.getByName("productionRelease")
                } else {
                    signingConfigs.getByName("debug")
                }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

val verifySaidianReleaseMode by tasks.registering {
    group = "verification"
    description = "Rejects ambiguous or unconfigured Saydian Release builds."
    doLast {
        if (productionReleaseRequested == qaReleaseAllowed) {
            throw GradleException(
                "Release builds require exactly one mode: " +
                    "SAIDIAN_PRODUCTION_RELEASE=true or SAIDIAN_ALLOW_QA_RELEASE=true",
            )
        }
        if (qaReleaseAllowed) {
            logger.warn("QA RELEASE - NOT FOR DISTRIBUTION; debug signing and disabled push are expected.")
            return@doLast
        }
        if (jpushAppKey.isEmpty() || jpushChannel != "production") {
            throw GradleException(
                "Production release requires JPUSH_APP_KEY and JPUSH_CHANNEL=production",
            )
        }
        if (jpushVendorChannels.isEmpty()) {
            throw GradleException("Production release requires an explicit JPUSH_VENDOR_CHANNELS decision")
        }
        if (!apiBaseUrl.startsWith("https://")) {
            throw GradleException("Production release requires an HTTPS SAYDIAN_API_BASE_URL")
        }
        if (!updateManifestUrl.startsWith("https://") || updateAllowedHosts.isEmpty()) {
            throw GradleException(
                "Production release requires an HTTPS SAYDIAN_UPDATE_MANIFEST_URL and " +
                    "SAYDIAN_UPDATE_ALLOWED_HOSTS",
            )
        }
        if (!hasCompleteProductionSigning) {
            throw GradleException(
                "Production release requires complete android/key.properties and its keystore file",
            )
        }
    }
}

tasks.matching {
    it.name.startsWith("pre") && it.name.endsWith("ReleaseBuild")
}.configureEach {
    dependsOn(verifySaidianReleaseMode)
    doFirst {
        if (emulatorDebugRequested) {
            throw GradleException(
                "SAIDIAN_EMULATOR_DEBUG=true is Debug-only and cannot be used for Release builds.",
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
    implementation(files(coolWearSdkFile))
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
