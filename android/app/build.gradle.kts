import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun decodeDartDefines(): Map<String, String> {
    val raw = project.findProperty("dart-defines") as? String ?: return emptyMap()
    return raw.split(",")
        .mapNotNull { entry ->
            try {
                val decoded = String(Base64.getDecoder().decode(entry), Charsets.UTF_8)
                val idx = decoded.indexOf('=')
                if (idx <= 0) null
                else decoded.substring(0, idx) to decoded.substring(idx + 1)
            } catch (_: Exception) {
                null
            }
        }
        .toMap()
}

val dartDefines = decodeDartDefines()
val useNextGenSdk =
    dartDefines["USE_NEXT_GEN_SDK"]?.equals("true", ignoreCase = true) == true

// GMA Next-Gen: exclude legacy play-services-ads pulled in by mediation adapters.
if (useNextGenSdk) {
    configurations.configureEach {
        exclude(group = "com.google.android.gms", module = "play-services-ads")
        exclude(group = "com.google.android.gms", module = "play-services-ads-lite")
    }
}

android {
    namespace = "com.voalearningenglish.listeningskills"
    compileSdk = maxOf(flutter.compileSdkVersion, 35)
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
        applicationId = "com.voalearningenglish.listeningskills"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
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
    implementation("androidx.media:media:1.7.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.android.gms:play-services-auth:21.3.0")
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")
    // play-services-ads / ads-mobile-sdk: do NOT pin here — google_mobile_ads plugin
    // selects legacy vs Next-Gen via --dart-define=USE_NEXT_GEN_SDK=true.

    // AdMob mediation — versions tested with GMA 25.4.0 / Next-Gen ~1.2–1.3
    implementation("com.google.ads.mediation:facebook:6.22.0.0")
    implementation("com.unity3d.ads:unity-ads:4.19.0")
    implementation("com.google.ads.mediation:unity:4.19.0.0")
    implementation("com.google.ads.mediation:applovin:13.6.3.0")
    implementation("com.google.ads.mediation:ironsource:9.5.0.0")
}
