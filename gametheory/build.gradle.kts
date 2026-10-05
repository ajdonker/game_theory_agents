plugins {
    kotlin("jvm")
    application
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

kotlin {
    jvmToolchain(21)
}

dependencies {
    implementation("io.github.jason-lang:jason-interpreter:3.2.1")
    implementation("it.unibo.tuprolog:solve-classic-jvm:1.1.5")
    implementation("it.unibo.tuprolog:parser-theory-jvm:1.1.5")

    testImplementation(kotlin("test-junit"))
}

sourceSets {
    main {
        resources {
            srcDir("src/main/asl")
        }
    }
}

application {
    mainClass.set("strips.Main")
}

val testJason by tasks.registering(JavaExec::class) {
    group = "verification"
    description = "Runs Jason AgentSpeak unit tests"

    dependsOn("classes")

    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("jason.infra.local.RunLocalMAS")

    workingDir = projectDir

    args(
        file("src/test/jason/unit_tests.mas2j").absolutePath
    )
}
tasks.test {
    useJUnit()
    dependsOn(testJason)
}

tasks.register<JavaExec>("runNoCommunication") {
    group = "application"
    description = "Runs the resource-management no communication Jason scenario"

    dependsOn("classes")

    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("jason.infra.local.RunLocalMAS")

    workingDir = projectDir
    args(file("NoCommunication.mas2j").absolutePath)

    standardInput = System.`in`
}

tasks.register<JavaExec>("runCentralizedCommunication") {
    group = "application"
    description = "Runs the resource-management centralized communication Jason scenario"

    dependsOn("classes")

    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("jason.infra.local.RunLocalMAS")

    workingDir = projectDir
    args(file("CentralCommunication.mas2j").absolutePath)

    standardInput = System.`in`
}

tasks.register<JavaExec>("runDecentralizedCommunication") {
    group = "application"
    description = "Runs the resource-management decentralized communication Jason scenario"

    dependsOn("classes")

    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("jason.infra.local.RunLocalMAS")

    workingDir = projectDir
    args(file("DecentralizedCommunication.mas2j").absolutePath)

    standardInput = System.`in`
}

tasks.register<Delete>("cleanSimulationResults") {
    delete(
        file("results/rounds.csv"),
        file("results/agents.csv"),
        file("results/strategies.csv")
    )
}

