plugins {
    kotlin("jvm") version "2.3.10"
}

allprojects {
    group = "it.unibo.ise"

    repositories {
        mavenCentral()
    }
}
dependencies {
    implementation(kotlin("stdlib-jdk8"))
}
repositories {
    mavenCentral()
}
kotlin {
    jvmToolchain(8)
}