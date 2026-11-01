package gui
import javax.swing.SwingUtilities

fun main() {
    println("Main started")

    SwingUtilities.invokeLater {
        try {
            lateinit var runner: JasonSimulationRunner

            val frame = SimulationFrame { config ->
                runner.start(config)
            }

            runner = JasonSimulationRunner( { status ->
                frame.setStatus(status)
            },
            { log ->
                frame.appendLog(log)
            },
            { event ->
                when (event) {
                    is SimulationEvent.RoundFinished ->
                        frame.updateProgress(event.round)

                    is SimulationEvent.InterventionApplied ->
                        frame.setStatus("Round ${event.round}: " +
                                "${event.mode} applied " +
                                "(success=${event.success})")

                    else -> {
                        // Handle other events for now do nothing.
                        Unit

                    }
                }
            })
            frame.isVisible = true

        } catch (e: Throwable) {
            e.printStackTrace()
        }
    }
}

