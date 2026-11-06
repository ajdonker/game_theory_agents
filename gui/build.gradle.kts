plugins {
    kotlin("jvm") version "2.3.10"
    application
}
dependencies {
    implementation(kotlin("stdlib-jdk8"))
    implementation("com.google.code.gson:gson:2.15.0")
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.4")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
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
    jvmToolchain(21)
}
tasks.test {
    useJUnitPlatform()
}