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
        // Must match the phone app's applicationId -- Play Console's "Wear
        // OS" form factor segment ties a release to the same app listing
        // as the phone only when both share one app ID.
        applicationId = "com.claudeusagemonitor.claude_usage_monitor"
        minSdk = 26
        targetSdk = 35
        // versionCode must be unique across the whole app (Play tracks it
        // per applicationId, not per form factor/segment) and always
        // increasing for this artifact's own release history -- it does
        // NOT need to match the phone's versionCode, since Play routes by
        // each artifact's declared device compatibility (uses-feature,
        // screen sizes, min/max SDK), not by version number. A fixed
        // +10000 offset from the phone's build number keeps this and the
        // phone's versionCode permanently out of each other's way; bump it
        // in lockstep with pubspec.yaml's build number (phone + 10000).
        versionCode = 10027
        versionName = "1.4.10"
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
    implementation("androidx.wear:wear-remote-interactions:1.0.0")
    implementation("androidx.wear.watchface:watchface-complications-data-source:1.3.0")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
}
