plugins {
    kotlin("jvm") version "2.3.10"
    application
}
dependencies {
    implementation(kotlin("stdlib-jdk8"))
    implementation("com.google.code.gson:gson:2.15.0")
}
application {
    mainClass.set("gui.MainKt")
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