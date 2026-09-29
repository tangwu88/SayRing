buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        val huaweiPushEnabled =
            System.getenv("JPUSH_VENDOR_CHANNELS")
                .orEmpty()
                .split(',')
                .any { it.trim().equals("huawei", ignoreCase = true) }
        if (huaweiPushEnabled) {
            // AGConnect 1.x still verifies that the legacy buildscript
            // classpath declares the Android Gradle Plugin coordinate.
            classpath("com.android.tools.build:gradle:9.0.1")
        }
    }
}

allprojects {
    repositories {
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        maven("https://maven.aliyun.com/repository/public")
        val yuchengPluginSource = gradle.extra.properties["yuchengPluginSource"] as? String
        if (yuchengPluginSource != null) {
            flatDir {
                dirs(file("$yuchengPluginSource/android/libs"))
            }
        }
        google()
        mavenCentral()
    }

    configurations.configureEach {
        resolutionStrategy {
            // Flutter's integration_test plugin still declares dynamic
            // AndroidX test versions. Pin the versions already used by this
            // project so release builds remain reproducible and do not need
            // Maven metadata access merely to package the application.
            force("androidx.test:runner:1.3.0")
            force("androidx.test:rules:1.2.0")
            force("androidx.test.espresso:espresso-core:3.3.0")
        }
    }
}

// The pinned Yucheng plugin publishes an unused Realtek bbpro 1.6.1 JAR via a
// broad `fileTree("*.jar")` dependency. QRing 1.0.0.76 embeds bbpro 1.9.4 and
// requires APIs that do not exist in 1.6.1, so keeping both makes D8 reject the
// APK for duplicate classes. Replace only that broad dependency with the other
// JAR it contains; Yucheng's AARs do not reference bbpro-core.
project(":yc_product_plugin").afterEvaluate {
    val apiDependencies = configurations.getByName("api").dependencies
    val jarTreeDependency =
        apiDependencies
            .filterIsInstance<org.gradle.api.artifacts.FileCollectionDependency>()
            .firstOrNull { dependency ->
                dependency.files.files.any { it.name == "rtk-bbpro-core-1.6.1.jar" }
            }
    if (jarTreeDependency != null) {
        apiDependencies.remove(jarTreeDependency)
        val yuchengPluginSource = gradle.extra.properties["yuchengPluginSource"] as String
        dependencies.add("api", files("$yuchengPluginSource/android/libs/Msc.jar"))
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
