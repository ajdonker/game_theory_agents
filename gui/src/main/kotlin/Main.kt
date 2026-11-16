package gui
import javax.swing.JOptionPane
import javax.swing.SwingUtilities

fun main() {
    SwingUtilities.invokeLater {
        try {
            lateinit var runner: JasonSimulationRunner
            lateinit var frame: SimulationFrame
            lateinit var startNextRun: () -> Unit

            var batchRuns = emptyList<ExperimentConfig>()
            var currentIndex = 0
            var batchRunning = false


            frame = SimulationFrame { baseConfig ->
                when {
                    batchRunning || runner.isRunning() -> {
                        frame.setStatus("A simulation is already running")
                    }

                    !frame.isBatchMode() -> {
                        frame.resetForNewRun(baseConfig)

                        if (!runner.start(baseConfig)) {
                            frame.setStatus("Could not start simulation")
                        }
                    }

                    else -> {
                        try {
                            val batchConfig = frame.readBatchConfig()

                            batchRuns = batchConfig.generate(baseConfig)
                            currentIndex = 0
                            batchRunning = true

                            frame.batchPanel.prepare(batchRuns)
                            startNextRun()

                        } catch (e: Exception) {
                            JOptionPane.showMessageDialog(
                                frame,
                                e.message ?: "Invalid batch configuration",
                                "Cannot start batch",
                                JOptionPane.ERROR_MESSAGE
                            )
                        }
                    }
                }
            }


            runner = JasonSimulationRunner(
                onStatus = { status ->
                    frame.setStatus(status)
                },
                onLog = { log ->
                    frame.appendLog(log)
                },
                onEvent = { event ->
                    frame.handleEvent(event)
                    frame.batchPanel.record(event)
                },
                onFinished = { exitCode ->
                    if (batchRunning) {
                        val success = exitCode == 0

                        frame.batchPanel.finishRun(success)

                        if (!success) {
                            batchRunning = false

                            frame.batchPanel.finishBatch(
                                "Batch stopped or failed at " +
                                        "run ${currentIndex + 1}"
                            )
                        } else {
                            currentIndex++

                            if (currentIndex < batchRuns.size) {
                                startNextRun()
                            } else {
                                batchRunning = false

                                frame.batchPanel.finishBatch(
                                    "Batch completed: " +
                                            "${batchRuns.size} runs"
                                )

                                frame.setStatus(
                                    "Batch completed successfully"
                                )
                            }
                        }
                    }
                }
            )

            startNextRun = {
                val config = batchRuns[currentIndex]


                frame.resetForNewRun(config)
                frame.batchPanel.startRun(currentIndex)

                if (!runner.start(config)) {
                    batchRunning = false
                    frame.batchPanel.finishRun(false)
                    frame.batchPanel.finishBatch(
                        "Failed to start run ${currentIndex + 1}"
                    )
                }
            }

            frame.isVisible = true

        } catch (e: Throwable) {
            e.printStackTrace()
        }
    }
}
