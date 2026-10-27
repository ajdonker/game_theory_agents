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

    testImplementation(kotlin("test-junit5"))
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.4")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}
tasks.test {
    useJUnitPlatform()
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
//
//val testJason by tasks.registering(JavaExec::class) {
//    group = "verification"
//    description = "Runs Jason AgentSpeak unit tests"
//
//    dependsOn("classes")
//
//    classpath = sourceSets["main"].runtimeClasspath
//    mainClass.set("jason.infra.local.RunLocalMAS")
//
//    workingDir = projectDir
//
//    args(
//        file("src/test/jason/unit_tests.mas2j").absolutePath
//    )
//}
//tasks.test {
//    useJUnit()
//    dependsOn(testJason)
//}

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

tasks.register<JavaExec>("runInterventions") {
    group = "application"
    description = "Runs the STRIPS-controlled intervention scenario"

    dependsOn("classes")

    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("jason.infra.local.RunLocalMAS")

    workingDir = projectDir
    args(file("Intervention.mas2j").absolutePath)
    args("--log-conf", file("console-logging.properties").absolutePath)

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
    args("--log-conf", file("console-logging.properties").absolutePath)
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

tasks.register<JavaExec>("runCoalitionCommunication") {
    group = "application"
    description = "Runs the resource-management coalition communication Jason scenario"

    dependsOn("classes")

    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("jason.infra.local.RunLocalMAS")

    workingDir = projectDir
    args(file("Coalition.mas2j").absolutePath)

    standardInput = System.`in`
}
tasks.register<JavaExec>("runHybridCentralizedCommunication") {
    group = "application"
    description = "Runs the hybrid strategy bid centralized communication Jason scenario"

    dependsOn("classes")

    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("jason.infra.local.RunLocalMAS")

    workingDir = projectDir
    args(file("Hybrid.mas2j").absolutePath)

    standardInput = System.`in`   
}
tasks.register<JavaExec>("runCoalitionStrategyCommunication") {
    group = "application"
    description = "Runs the resource-management coalition strategy communication Jason scenario"

    dependsOn("classes")

    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("jason.infra.local.RunLocalMAS")

    workingDir = projectDir
    args(file("DecentralizedStrategy.mas2j").absolutePath)

    standardInput = System.`in`
}
tasks.register<JavaExec>("runDecentralizedStrategyCommunication") {
    group = "application"
    dependsOn("classes")
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("jason.infra.local.RunLocalMAS")
    workingDir = projectDir
    args(file("DecentralizedStrategyCommunication.mas2j").absolutePath)
    standardInput = System.`in`
}
tasks.register<Delete>("cleanSimulationResults") {
    delete(
        file("results/no_comm/rounds.csv"),
        file("results/no_comm/agents.csv"),
        file("results/no_comm/strategies.csv"),
        file("results/centralized/rounds.csv"),
        file("results/centralized/agents.csv"),
        file("results/centralized/strategies.csv"),
        file("results/decentralized/rounds.csv"),
        file("results/decentralized/agents.csv"),
        file("results/decentralized/strategies.csv"),
        file("results/coalition/rounds.csv"),
        file("results/coalition/agents.csv"),
        file("results/coalition/strategies.csv"),
        file("results/adaptive/rounds.csv"),
        file("results/adaptive/agents.csv"),
        file("results/adaptive/strategies.csv")
    )
}
tasks.register<Delete>("cleanCentralizedResults") {
    group = "verification"
    description = "Cleans centralized simulation CSV files"

    delete(
        fileTree("results/centralized") {
            include("*.csv")
        }
    )
}
tasks.register<Delete>("cleanDecentralizedResults") {
    group = "verification"
    description = "Cleans decentralized simulation CSV files"

    delete(
        fileTree("results/decentralized") {
            include("*.csv")
        }
    )
}
tasks.register<Delete>("cleanInterventionResults") {
    group = "verification"
    description = "Cleans intervention simulation CSV files"

    delete (
        fileTree("results/adaptive") {
            include("*.csv")
        }
    )
}
