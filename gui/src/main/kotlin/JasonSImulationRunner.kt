package gui

import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import javax.swing.SwingUtilities
import kotlin.concurrent.thread

class JasonSimulationRunner(
    private val onStatus: (String) -> Unit,
    private val onLog: (String) -> Unit,
    private val onEvent: (SimulationEvent) -> Unit,
    private val commandFactory: (ExperimentConfig) -> List<String> = ::defaultCommand,
    private val workingDirectory: File = findGradleRoot()
) {
    private val running = AtomicBoolean(false)
    private val stopping = AtomicBoolean(false)
    private val lock = Any()
    private var process: Process? = null

    fun isRunning(): Boolean = running.get()

    fun start(config: ExperimentConfig): Boolean {
        val invalid = runCatching { validate(config) }.exceptionOrNull()
        if (invalid != null) {
            postStatus("Invalid configuration: ${invalid.message}")
            return false
        }
        if (!running.compareAndSet(false, true)) {
            postStatus("Already running")
            return false
        }
        stopping.set(false)

        thread(name = "jason-simulation", isDaemon = true) {
            var terminal = "Failed: unknown error"
            try {
                val command = commandFactory(config)
                val p = ProcessBuilder(command)
                    .directory(workingDirectory)
                    .redirectErrorStream(true)
                    .start()

                synchronized(lock) {
                    process = p
                    if (stopping.get()) terminate(p)
                }
                if (!stopping.get()) postStatus("Running ${config.scenario}")

                var completedEvent = false
                p.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach { line ->
                        SwingUtilities.invokeLater { onLog(line) }
                        SimulationEventParser.parse(line)?.let { event ->
                            if (event is SimulationEvent.SimulationFinished) completedEvent = true
                            SwingUtilities.invokeLater { onEvent(event) }
                        }
                    }
                }
                val exitCode = p.waitFor()
                terminal = when {
                    stopping.get() -> "Stopped"
                    exitCode != 0 -> "Failed: process exit $exitCode"
                    !completedEvent -> "Failed: missing simulation_finished event"
                    else -> "Completed"
                }
            } catch (e: Exception) {
                terminal = if (stopping.get()) "Stopped" else "Failed: ${e.message}"
            } finally {
                synchronized(lock) { process = null }
                running.set(false)
                postStatus(terminal)
            }
        }
        return true
    }

    fun stop() {
        if (!running.get()) return
        stopping.set(true)
        synchronized(lock) { process?.let(::terminate) }
    }

    private fun postStatus(message: String) {
        SwingUtilities.invokeLater { onStatus(message) }
    }

    private fun terminate(p: Process) {
        p.toHandle().descendants().toList().asReversed().forEach { child ->
            if (child.isAlive) child.destroyForcibly()
        }
        p.destroyForcibly()
    }
}

private fun validate(config: ExperimentConfig) {
    require(config.runId in 1..1_000_000) { "Run ID must be between 1 and 1000000" }
    require(config.seed >= 0) { "Seed must be nonnegative" }
    require(config.rounds in 1..1_000_000) { "Rounds must be between 1 and 1000000" }
}

private fun findGradleRoot(): File =
    generateSequence(File(System.getProperty("user.dir")).absoluteFile) { it.parentFile }
        .firstOrNull { File(it, "gradlew").isFile }
        ?: error("Cannot find root containing gradlew")

private fun defaultCommand(config: ExperimentConfig): List<String> {
    val task = when (config.scenario) {
        Scenario.NO_COMM -> ":gametheory:runNoCommunication"
        Scenario.CENTRALIZED -> ":gametheory:runCentralizedCommunication"
        Scenario.DECENTRALIZED -> ":gametheory:runDecentralizedCommunication"
        Scenario.COALITION -> ":gametheory:runCoalitionCommunication"
        Scenario.ADAPTIVE -> ":gametheory:runInterventions"
    }
    return listOf(
        "./gradlew", "--console=plain",
        "-PcprRunId=${config.runId}",
        "-PcprSeed=${config.seed}",
        "-PcprRounds=${config.rounds}",
        task
    )
}