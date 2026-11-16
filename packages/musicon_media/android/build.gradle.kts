plugins {
    id("com.android.library")
    id("kotlin-android")
}

group = "com.musicon.musicon"
version = "0.1.0"

android {
    namespace = "com.musicon.media"
    compileSdk = 36
    defaultConfig { minSdk = 24 }
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
}

dependencies {
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.github.TeamNewPipe:NewPipeExtractor:v0.27.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
    testImplementation("junit:junit:4.13.2")
}
