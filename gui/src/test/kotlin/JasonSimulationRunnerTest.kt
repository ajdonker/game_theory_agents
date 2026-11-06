package gui

import java.io.File
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

// Fake child processes use the runner without starting Jason/Gradle.
class JasonSimulationRunnerTest {
    private fun config(rounds: Int = 1) =
        ExperimentConfig(1, 42L, rounds, Scenario.NO_COMM)

    private fun awaitStatus(
        queue: LinkedBlockingQueue<String>,
        predicate: (String) -> Boolean
    ): String {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(10)
        while (System.nanoTime() < deadline) {
            val message = queue.poll(200, TimeUnit.MILLISECONDS) ?: continue
            if (predicate(message)) return message
        }
        fail<String>("Expected status not received")
        error("unreachable")
    }

    private fun runner(
        script: String,
        statuses: LinkedBlockingQueue<String>,
        events: LinkedBlockingQueue<SimulationEvent> = LinkedBlockingQueue()
    ) = JasonSimulationRunner(
        onStatus = { statuses.add(it) },
        onLog = { },
        onEvent = { events.add(it) },
        commandFactory = { listOf("bash", "-c", script) },
        workingDirectory = File(".")
    )

    @Test
    fun `normal subprocess forwards events and completes`() {
        val statuses = LinkedBlockingQueue<String>()
        val events = LinkedBlockingQueue<SimulationEvent>()
        val json = """CPR_EVENT|{"type":"simulation_finished","round":1}"""
        val r = runner("printf '%s\\n' '$json'", statuses, events)
        assertTrue(r.start(config()))
        assertEquals("Completed", awaitStatus(statuses) { it == "Completed" })
        assertInstanceOf(SimulationEvent.SimulationFinished::class.java,
            events.poll(2, TimeUnit.SECONDS))
    }

    @Test
    fun `nonzero process exit is reported as failure`() {
        val statuses = LinkedBlockingQueue<String>()
        val r = runner("exit 7", statuses)
        assertTrue(r.start(config()))
        assertTrue(awaitStatus(statuses) { it.startsWith("Failed:") }.contains("7"))
    }

    @Test
    fun `zero exit without completion event is not counted as success`() {
        val statuses = LinkedBlockingQueue<String>()
        val r = runner("echo started", statuses)
        assertTrue(r.start(config()))
        assertTrue(awaitStatus(statuses) { it.startsWith("Failed:") }.contains("missing"))
    }

    @Test
    fun `stop terminates a long running subprocess`() {
        val statuses = LinkedBlockingQueue<String>()
        val r = runner("echo started; sleep 30", statuses)
        assertTrue(r.start(config()))
        awaitStatus(statuses) { it.startsWith("Running") }
        r.stop()
        assertEquals("Stopped", awaitStatus(statuses) { it == "Stopped" })
        assertFalse(r.isRunning())
    }

    @Test
    fun `overlapping run is rejected`() {
        val statuses = LinkedBlockingQueue<String>()
        val r = runner("sleep 30", statuses)
        assertTrue(r.start(config()))
        assertFalse(r.start(config()))
        awaitStatus(statuses) { it == "Already running" }
        r.stop()
        awaitStatus(statuses) { it == "Stopped" }
    }

    @Test
    fun `invalid configuration never starts a subprocess`() {
        val statuses = LinkedBlockingQueue<String>()
        val r = runner("exit 0", statuses)
        assertFalse(r.start(config(rounds = 0)))
        awaitStatus(statuses) { it.startsWith("Invalid configuration") }
        assertFalse(r.isRunning())
    }

    @Test
    fun `same runner can run again after completion`() {
        val statuses = LinkedBlockingQueue<String>()
        val json = """CPR_EVENT|{"type":"simulation_finished","round":1}"""
        val r = runner("printf '%s\\n' '$json'", statuses)
        assertTrue(r.start(config()))
        awaitStatus(statuses) { it == "Completed" }
        assertTrue(r.start(config()))
        awaitStatus(statuses) { it == "Completed" }
    }
}