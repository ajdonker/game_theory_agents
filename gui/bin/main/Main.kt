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
            })
            frame.isVisible = true

        } catch (e: Throwable) {
            e.printStackTrace()
        }
    }
}

