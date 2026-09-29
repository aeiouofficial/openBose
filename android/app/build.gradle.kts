plugins {
    id("com.android.application")
    kotlin("android")
}

repositories {
    google()
    mavenCentral()
}

android {
    namespace = "dev.openbose.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "dev.openbose.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 2
        versionName = rootProject.file("../VERSION").readText().trim()
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation(project(":bmap"))
    implementation(project(":audio"))
}
