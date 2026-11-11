import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La chiave di firma sta fuori dal repo: android/key.properties punta al file .jks.
// Senza, la build release si firma con la chiave di debug (va bene per provare, non per distribuire).
val keyProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.pasao.transcrify"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.pasao.transcrify"
        // Android 12 e successivi.
        minSdk = 31
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Solo telefoni a 64 bit (ARM): da Android 12 sono praticamente tutti. Il motore del modello
        // degli argomenti pesa 34 MB per architettura: tenerne una sola toglie circa 65 MB all'app.
        ndk { abiFilters += listOf("arm64-v8a") }
    }

    signingConfigs {
        if (keyProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    // Il filtro qui sopra non basta per le librerie che arrivano già compilate (ONNX Runtime le porta per tre
    // architetture: 65 MB in più). Solo arm64, come dice il filtro (11 nov).
    packaging {
        jniLibs {
            excludes += listOf("lib/armeabi-v7a/**", "lib/x86_64/**", "lib/x86/**")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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

// I test col modello vero sul PC: su Windows il Java di Android Studio porta un msvcp140.dll
// troppo vecchio per ONNX Runtime, quindi se ne può indicare un altro solo per i test (vedi TestModels).
tasks.withType<Test>().configureEach {
    providers.environmentVariable("TRANSCRIFY_TEST_JAVA").orNull?.let { executable = it }
}

android {
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.08.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    // Solo per i calcoli dei colori di Material You (Hct, SchemeFidelity, Blend): la fonte unica dei token (Token.kt).
    implementation("com.google.android.material:material:1.13.0")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.compose.material:material-icons-extended:1.7.8")
    testImplementation("junit:junit:4.13.2")
    // Il modello degli argomenti sul telefono. Il pacchetto completo (non «mobile»): Gemma in 4 bit
    // usa operatori di Microsoft (MatMulNBits, GatherBlockQuantized, MultiHeadAttention…).
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.31.1")
    // Nei test sul PC la stessa versione, con le librerie per Windows, Linux e Mac.
    testImplementation("com.microsoft.onnxruntime:onnxruntime:1.31.1")
    // Per leggere il tokenizer.json (20 MB) a flusso, uguale sul telefono e sul PC.
    implementation("com.google.code.gson:gson:2.13.2")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.10.0")
    implementation("androidx.savedstate:savedstate-ktx:1.4.0")
}
