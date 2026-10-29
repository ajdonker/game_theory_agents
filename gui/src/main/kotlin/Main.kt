
import javax.swing.SwingUtilities

fun main() {
    println("Main started")

    SwingUtilities.invokeLater {
        try {
            lateinit var runner: JasonSimulationRunner

            val frame = SimulationFrame { config ->
                runner.start(config)
            }

            runner = JasonSimulationRunner { status ->
                frame.setStatus(status)
            }

            frame.isVisible = true

        } catch (e: Throwable) {
            e.printStackTrace()
        }
    }
}

