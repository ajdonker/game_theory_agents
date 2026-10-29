plugins {
    kotlin("jvm") version "2.3.10"
    application
}
dependencies {
    implementation(kotlin("stdlib-jdk8"))
}
application {
    mainClass.set("MainKt")
}
allprojects {
    group = "it.unibo.ise"

    repositories {
        mavenCentral()
    }
}
repositories {
    mavenCentral()
}
kotlin {
    jvmToolchain(8)
}