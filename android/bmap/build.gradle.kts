plugins {
    kotlin("jvm")
}

kotlin { jvmToolchain(17) }

dependencies {
    testImplementation(kotlin("test-junit5"))
    testImplementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test { useJUnitPlatform() }

sourceSets.test {
    resources.srcDir("../../spec/bmap")
}
