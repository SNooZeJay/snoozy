plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

val releaseStoreFile = System.getenv("SNOOZY_KEYSTORE_FILE")

android {
    namespace = "com.snoozy.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.snoozy.app"
        minSdk = 33
        targetSdk = 37
        versionCode = 14
        versionName = "3.0.0"

        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = System.getenv("SNOOZY_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("SNOOZY_KEY_ALIAS")
                keyPassword = System.getenv("SNOOZY_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            // Debug stays installable over the 2.3.0 release build and keeps run-as.
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (releaseStoreFile != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    buildFeatures {
        compose = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    implementation("io.github.neoruaa.glasmio:glasmio-scaffold:0.1.2")
    implementation("br.com.devsrsouza.compose.icons:feather:1.1.1")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("com.tencent:mmkv:2.4.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    implementation("io.coil-kt.coil3:coil-compose:3.6.3")
    implementation("androidx.media3:media3-exoplayer:1.11.0")
    implementation("androidx.media3:media3-session:1.11.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.12.0")
    androidTestImplementation(platform("androidx.compose:compose-bom:2026.09.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
