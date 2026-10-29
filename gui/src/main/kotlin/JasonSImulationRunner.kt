
import java.io.File
import javax.swing.SwingUtilities
import kotlin.concurrent.thread

class JasonSimulationRunner(
    private val onStatus: (String) -> Unit
) {
    @Volatile
    private var running = false

    @Volatile
    private var process: Process? = null

    fun start(config: ExperimentConfig) {
        if (running) {
            updateStatus("Simulation already running")
            return
        }

        running = true

        thread(name = "jason-runner", isDaemon = true) {
            try {
                // Find the project root containing gradlew
                val projectRoot = generateSequence(
                    File(System.getProperty("user.dir")).absoluteFile
                ) { it.parentFile }
                    .firstOrNull { File(it, "gradlew").isFile }
                    ?: error("Cannot find Gradle project root")

                // Select the Gradle task
                val task = when (config.scenario) {
                    Scenario.NO_COMM ->
                        ":gametheory:runNoCommunication"

                    Scenario.CENTRALIZED ->
                        ":gametheory:runCentralizedCommunication"

                    Scenario.DECENTRALIZED ->
                        ":gametheory:runDecentralizedCommunication"

                    Scenario.COALITION ->
                        ":gametheory:runCoalitionCommunication"

                    Scenario.ADAPTIVE ->
                        ":gametheory:runInterventions"
                }

                updateStatus("Launching ${config.scenario}...")

                val builder = ProcessBuilder(
                    "./gradlew",
                    "--console=plain",
                    task
                )

                builder.directory(projectRoot)
                builder.redirectErrorStream(true)

                val currentProcess = builder.start()
                process = currentProcess

                updateStatus("Running ${config.scenario}")

                // Read output without blocking Swing
                currentProcess.inputStream
                    .bufferedReader()
                    .useLines { lines ->
                        lines.forEach { line ->
                            println("[Jason] $line")
                        }
                    }

                val exitCode = currentProcess.waitFor()

                if (exitCode == 0) {
                    updateStatus("Simulation completed")
                } else {
                    updateStatus("Simulation failed: $exitCode")
                }

            } catch (e: Exception) {
                e.printStackTrace()
                updateStatus("Error: ${e.message}")
            } finally {
                process = null
                running = false
            }
        }
    }

    fun stop() {
        process?.destroy()
    }

    private fun updateStatus(message: String) {
        SwingUtilities.invokeLater {
            onStatus(message)
        }
    }
}
