package simulation

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import java.util.Locale
import kotlin.math.abs

/**
 * Post-run batch validation for NFR4 (30 independent runs x 300 rounds),
 * NFR5 (data consistency), and FR1/FR9 (economic results and logging).
 *
 * FIRST execute the batch using the existing GUI batch mode or Bash scripts.
 * This JUnit test DOES NOT start simulations: it checks the CSVs already saved
 * in results/<scenario>/rounds.csv and agents.csv.
 *
 * Defaults: scenario=adaptive, 30 runs, 300 rounds per run,
 *           first run ID=1, first seed=42, incrementing run IDs and seeds.
 *
 * Override with:
 *   ISE_BATCH_SCENARIO        (default adaptive)
 *   ISE_BATCH_RUNS            (default 30)
 *   ISE_BATCH_ROUNDS          (default 300)
 *   ISE_BATCH_RUN_ID_START    (default 1)
 *   ISE_BATCH_SEED_START      (default 42)
 *   ISE_BATCH_RUN_ID_MODE     (increment or fixed; default increment)
 *
 * The 'fixed' mode is for batches where every seed uses the SAME run ID.
 * Example: ISE_BATCH_RUN_ID_START=3 ISE_BATCH_RUN_ID_MODE=fixed.
 *
 * Run from the repository root:
 *   ./gradlew :gametheory:test \
 *     --tests 'simulation.BatchValidationTest' --rerun-tasks
 *
 * Passing proves the saved batch has exactly the configured runs, rounds,
 * agent observations and correct payoffs. CSVs alone cannot prove elapsed
 * execution time or whether the runs required manual intervention.
 */
class BatchValidationTest {
    private fun envInt(name: String, default: Int): Int =
        System.getenv(name)?.let { value ->
            value.toIntOrNull() ?: error("$name must be an integer, got '$value'")
        } ?: default

    private val scenario = (System.getenv("ISE_BATCH_SCENARIO") ?: "adaptive").also {
        require(it.matches(Regex("[a-zA-Z_]+"))) { "Invalid scenario name: $it" }
    }
    private val expectedRuns = envInt("ISE_BATCH_RUNS", 30).also { require(it > 0) }
    private val expectedRounds = envInt("ISE_BATCH_ROUNDS", 300).also { require(it > 0) }
    private val firstRunId = envInt("ISE_BATCH_RUN_ID_START", 1)
    private val firstSeed = envInt("ISE_BATCH_SEED_START", 42)
    private val runIdMode = (System.getenv("ISE_BATCH_RUN_ID_MODE") ?: "increment").also {
        require(it == "increment" || it == "fixed") {
            "ISE_BATCH_RUN_ID_MODE must be 'increment' or 'fixed', got '$it'"
        }
    }

    private val expectedAgents = (1..8).map { "agent$it" }.toSet()
    private val epsilon = 1e-5

    private data class Key(val runId: Int, val seed: Int)

    private fun keys(): List<Key> = (0 until expectedRuns).map { offset ->
        Key(if (runIdMode == "fixed") firstRunId else firstRunId + offset,
            firstSeed + offset)
    }

    private fun inputFile(filename: String): Path {
        val fromModule = Path.of("results", scenario, filename)
        val fromRoot = Path.of("gametheory", "results", scenario, filename)
        val path = if (Files.exists(fromModule)) fromModule else fromRoot
        require(Files.isRegularFile(path)) {
            "Missing $path. Run the $scenario batch and save results first."
        }
        return path
    }

    private fun intField(value: String): Int {
        val number = value.toDouble()
        require(number.isFinite() && number % 1.0 == 0.0) { "Not an integer: '$value'" }
        return number.toInt()
    }

    private fun doubleField(value: String): Double = value.toDouble().also {
        require(it.isFinite()) { "Non-finite CSV value: '$value'" }
    }

    private fun allRows(filename: String, expectedColumns: Int): List<List<String>> =
        Files.readAllLines(inputFile(filename)).mapNotNull { line ->
            if (line.isBlank()) return@mapNotNull null
            val cells = line.split(',').map { it.trim() }
            if (cells.firstOrNull()?.toDoubleOrNull() == null) return@mapNotNull null // header
            require(cells.size == expectedColumns) {
                "Malformed $filename row (expected $expectedColumns columns): $line"
            }
            cells
        }

    @Test
    fun `batch has all requested runs and economically consistent rounds`() {
        val expectedKeys = keys()
        assertEquals(expectedRuns, expectedKeys.toSet().size,
            "Batch configuration produces duplicate (run ID, seed) combinations")
        assertEquals(expectedRuns, expectedKeys.map { it.seed }.toSet().size,
            "Independent runs require distinct random seeds")

        val roundsByRun = allRows("rounds.csv", 7)
            .groupBy { Key(intField(it[0]), intField(it[1])) }
        val agentsByRun = allRows("agents.csv", 9)
            .groupBy { Key(intField(it[0]), intField(it[1])) }

        var totalValidatedRounds = 0
        var totalValidatedAgents = 0
        var totalRentPercentage = 0.0

        for (key in expectedKeys) {
            val roundRows = roundsByRun[key].orEmpty()
            val agentRows = agentsByRun[key].orEmpty()

            assertEquals((1..expectedRounds).toList(),
                roundRows.map { intField(it[2]) }.sorted(),
                "Missing or duplicated rounds for run ID ${key.runId}, seed ${key.seed}")
            assertEquals(expectedRounds * 8, agentRows.size,
                "Wrong agent record count for run ID ${key.runId}, seed ${key.seed}")

            val byRound = agentRows.groupBy { intField(it[2]) }
            for (roundRow in roundRows) {
                val round = intField(roundRow[2])
                val agents = byRound[round].orEmpty()
                assertEquals(8, agents.size, "Expected 8 agents for $key, round $round")
                assertEquals(expectedAgents, agents.map { it[3] }.toSet(),
                    "Missing or duplicated agent names for $key, round $round")

                val bids = agents.map { doubleField(it[5]) }
                assertTrue(bids.all { it in 0.0..10.0 }, "Illegal bid for $key, round $round")
                val total = bids.sum()
                val rent = total * (23.0 - 0.25 * total) - 5.0 * total
                val rentPercentage = 100.0 * rent / 324.0

                assertEquals(total, doubleField(roundRow[3]), epsilon,
                    "Wrong total investment for $key, round $round")
                assertEquals(total / 8.0, doubleField(roundRow[4]), epsilon,
                    "Wrong average investment for $key, round $round")
                assertEquals(rent, doubleField(roundRow[5]), epsilon,
                    "Wrong group rent for $key, round $round")
                assertEquals(rentPercentage, doubleField(roundRow[6]), epsilon,
                    "Wrong rent percentage for $key, round $round")

                for (agent in agents) {
                    val bid = doubleField(agent[5])
                    val market1 = 5.0 * (10.0 - bid)
                    val market2 = bid * (23.0 - 0.25 * total)
                    assertEquals(market1, doubleField(agent[6]), epsilon,
                        "Wrong market 1 payoff for $key, round $round, ${agent[3]}")
                    assertEquals(market2, doubleField(agent[7]), epsilon,
                        "Wrong market 2 payoff for $key, round $round, ${agent[3]}")
                    assertEquals(market1 + market2, doubleField(agent[8]), epsilon,
                        "Wrong total payoff for $key, round $round, ${agent[3]}")
                }
                totalRentPercentage += rentPercentage
            }
            totalValidatedRounds += roundRows.size
            totalValidatedAgents += agentRows.size
            println("PASS: runId=${key.runId}, seed=${key.seed}, " +
                    "rounds=${roundRows.size}, agents=${agentRows.size}")
        }

        assertEquals(expectedRuns * expectedRounds, totalValidatedRounds)
        assertEquals(expectedRuns * expectedRounds * 8, totalValidatedAgents)
        val meanRent = totalRentPercentage / totalValidatedRounds
        println("BATCH PASS: scenario=$scenario, runs=$expectedRuns, " +
                "rounds=$totalValidatedRounds, agent observations=$totalValidatedAgents, " +
                "mean rent=${String.format(Locale.US, "%.2f", meanRent)}% of optimum")
    }
}