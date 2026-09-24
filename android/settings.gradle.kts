pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

rootProject.name = "openBose-android"
include(":bmap")
// Keep offline protocol tests lightweight. An Android APK build opts in with -PwithAndroidApp=true.
if (providers.gradleProperty("withAndroidApp").orNull == "true") include(":app")
