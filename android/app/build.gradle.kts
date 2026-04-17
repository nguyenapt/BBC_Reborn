plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.learningenglish.studyingbbc.bbc_reborn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.learningenglish.studyingbbc.bbc_reborn"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = "bbc-release"
            keyPassword = "Nguyen142093211"
            storeFile = file("keystore/bbc-release-key.keystore")
            storePassword = "Nguyen142093211"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")
    // Khớp google_mobile_ads plugin (play-services-ads 23.6.0)
    implementation("com.google.android.gms:play-services-ads:23.6.0")
    // AdMob mediation — tương thích GMA 23.6.0 (googleads-mobile-android-mediation CHANGELOG)
    implementation("com.google.ads.mediation:facebook:6.19.0.0")
    implementation("com.unity3d.ads:unity-ads:4.13.1")
    implementation("com.google.ads.mediation:unity:4.13.1.0")
    // AppLovin (AdMob mediation) — 13.1.0.0 tested với GMA 23.6.0; hoạt động khi bạn bật nguồn trên Console
    implementation("com.google.ads.mediation:applovin:13.1.0.0")
    // ironSource (LevelPlay) AdMob mediation adapter
    implementation("com.google.ads.mediation:ironsource:9.3.0.2")
}
