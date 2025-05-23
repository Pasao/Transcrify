plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.test.transcrify"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.test.transcrify"
        minSdk = 34
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    buildFeatures {
        compose = true
    }
}

dependencies {

    // Core Android & Jetpack
    implementation(libs.androidx.material.icons.extended)

    // Secure Storage for API Key
    implementation("androidx.security:security-crypto-ktx:1.1.0-alpha06")

    implementation (libs.androidx.runtime) // O la versione più recente
    implementation (libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    implementation("com.squareup.retrofit2:retrofit:2.11.0") // Verifica ultima versione
    implementation("com.squareup.retrofit2:converter-gson:2.9.0") // O altro converter
    // OkHttp (necessario per Retrofit)
    implementation("com.squareup.okhttp3:okhttp:4.12.0") // O versione più recente
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0") // Opzionale ma util
    // DataStore Preferences
    implementation("androidx.datastore:datastore-preferences:1.1.4")

    //implementation("io.github.luiisca:floating.views:1.0.5") //prima cerca nel MavenLocal
    implementation("io.github.luiisca:floating.views:1.0.5-lifecycle")

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.material)
    implementation(libs.androidx.games.activity)
    implementation(libs.androidx.security.crypto.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose.android)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}