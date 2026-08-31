import java.io.FileInputStream
import java.util.Properties

val keyFile = rootProject.file("key.properties")
val keyProperties = Properties()
val hasReleaseKey = keyFile.exists()
if (hasReleaseKey) keyProperties.load(FileInputStream(keyFile))

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.claudeusagemonitor.claude_usage_monitor.wear"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.claudeusagemonitor.claude_usage_monitor.wear"
        minSdk = 26
        targetSdk = 35
        versionCode = 16
        versionName = "1.3.2"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.wear:wear:1.3.0")
    implementation("androidx.wear.watchface:watchface-complications-data-source:1.3.0")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
}
