package gui

import java.awt.Component
import java.awt.Container
import java.awt.GraphicsEnvironment
import javax.swing.JButton
import javax.swing.JFrame
import javax.swing.JLabel
import javax.swing.JProgressBar
import javax.swing.JSpinner
import javax.swing.JTable
import javax.swing.JTextArea
import javax.swing.SwingUtilities
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Assumptions.assumeFalse
import org.junit.jupiter.api.Test

class SimulationFrameTest {
    /* Test whether SimulationFrame correctly updates its GUI components in response to SimulationEventParser events, and resets state on new run. */
    private fun find(root: Component, name: String): Component? {
        if (root.name == name) return root
        if (root is Container) for (child in root.components) {
            find(child, name)?.let { return it }
        }
        return null
    }

    private inline fun <reified T : Component> named(frame: JFrame, name: String): T =
        requireNotNull(find(frame.contentPane, name) as? T) {
            "Missing ${T::class.java.simpleName} named '$name'"
        }

    @Test
    fun `parsed events update progress metrics agents interventions and summary`() {
        assumeFalse(GraphicsEnvironment.isHeadless(), "Swing JFrame needs a display; run with xvfb-run")
        SwingUtilities.invokeAndWait {
            val frame = SimulationFrame { }
            try {
                frame.resetProgress(5)
                val roundLine = """CPR_EVENT|{"type":"round_finished","round":5,"totalInvestment":72,"rentPct":0,"distanceToOptimum":36}"""
                frame.handleEvent(requireNotNull(SimulationEventParser.parse(roundLine)))
                assertEquals(5, named<JProgressBar>(frame, "progressBar").value)
                assertTrue(named<JLabel>(frame, "metricsLabel").text.contains("72"))

                frame.handleEvent(SimulationEvent.AgentResult(5, "agent1", 9.0, 50.0, "adaptive"))
                frame.handleEvent(SimulationEvent.AgentResult(5, "agent2", 8.0, 52.0, "adaptive"))
                assertEquals(2, named<JTable>(frame, "agentTable").rowCount)

                frame.handleEvent(SimulationEvent.InterventionDecision(5, "none", "centralized", "decentralized", 2, 0))
                frame.handleEvent(SimulationEvent.InterventionApplied(5, "decentralized", true))
                val decisions = named<JTextArea>(frame, "interventionArea").text
                assertTrue(decisions.contains("centralized"))
                assertTrue(decisions.contains("decentralized"))

                frame.handleEvent(SimulationEvent.PlannerDecision(5, listOf("high"), listOf("share"), "decentralized"))
                frame.handleEvent(SimulationEvent.PlannerFailed(5, "test failure"))
                assertTrue(named<JTextArea>(frame, "plannerArea").text.contains("share"))
                frame.handleEvent(SimulationEvent.CoalitionChanged(5, "c1", listOf("agent1", "agent2"), "formed"))
                assertTrue(named<JTextArea>(frame, "coalitionArea").text.contains("agent1"))

                frame.handleEvent(SimulationEvent.SimulationFinished(5))
                val summary = named<JTextArea>(frame, "summaryArea").text
                assertTrue(summary.contains("5"))
                assertTrue(summary.contains("36"))
            } finally {
                frame.dispose()
            }
        }
    }

    @Test
    fun `starting a new run resets old observations and invokes callback`() {
        assumeFalse(GraphicsEnvironment.isHeadless(), "Swing JFrame needs a display; run with xvfb-run")
        SwingUtilities.invokeAndWait {
            val started = mutableListOf<ExperimentConfig>()
            val frame = SimulationFrame { config -> started.add(config) }
            try {
                frame.handleEvent(SimulationEvent.AgentResult(1, "agent1", 3.0, 25.0, "adaptive"))
                frame.handleEvent(SimulationEvent.InterventionApplied(1, "centralized", true))
                named<JSpinner>(frame, "roundsSpinner").value = 5
                named<JButton>(frame, "startButton").doClick()

                assertEquals(1, started.size)
                assertEquals(5, started.single().rounds)
                assertEquals(0, named<JTable>(frame, "agentTable").rowCount)
                assertEquals("", named<JTextArea>(frame, "interventionArea").text)
                assertEquals(5, named<JProgressBar>(frame, "progressBar").maximum)
            } finally {
                frame.dispose()
            }
        }
    }
}