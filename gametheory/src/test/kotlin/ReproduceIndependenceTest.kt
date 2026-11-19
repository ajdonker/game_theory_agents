package simulation

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path

/**
 * Post-run reproducibility and isolation validation (NFR1, NFR2, NFR5).
 *
 * Prepare THREE independent runs of the SAME scenario, in this order:
 *   A: runId=901, seed=42; B: runId=902, seed=43;
 *   A again: runId=903, seed=42. All must have the same round count.
 * The intervening B run helps detect mutable state leaking into A again.
 *
 * Defaults: scenario=no_comm, rounds=100; run IDs=901/902/903, seeds=42/43/42.
 * Override using ISE_REPRO_SCENARIO, ISE_REPRO_ROUNDS, ISE_REPRO_FIRST_RUN_ID,
 * ISE_REPRO_MIDDLE_RUN_ID, ISE_REPRO_LAST_RUN_ID,
 * ISE_REPRO_SEED, ISE_REPRO_OTHER_SEED.
 *
 * CSVs must exist under results/<scenario>/rounds.csv and agents.csv;
 * strategies.csv is also compared for no_comm.
 *
 * Example (after generating the runs):
        ISE_REPRO_SCENARIO=adaptive \
        ISE_REPRO_ROUNDS=300 \
        ISE_REPRO_FIRST_RUN_ID=901 \
        ISE_REPRO_MIDDLE_RUN_ID=902 \
        ISE_REPRO_LAST_RUN_ID=903 \
        ISE_REPRO_SEED=42 \
        ISE_REPRO_OTHER_SEED=43 \
        ./gradlew :gametheory:test \
        --tests 'simulation.ReproducibilityAndIndependenceTest' \
        --rerun-tasks
 * This is a post-run integration test, not a test that starts the MAS.
 */
class ReproducibilityAndIndependenceTest {
    private fun envInt(name: String, fallback: Int): Int =
        System.getenv(name)?.let { raw ->
            raw.toIntOrNull() ?: error("$name must be an integer (was '$raw')")
        } ?: fallback

    private val scenario = System.getenv("ISE_REPRO_SCENARIO") ?: "no_comm"
    private val expectedRounds = envInt("ISE_REPRO_ROUNDS", 100).also { require(it > 0) }
    private val firstRunId = envInt("ISE_REPRO_FIRST_RUN_ID", 901)
    private val middleRunId = envInt("ISE_REPRO_MIDDLE_RUN_ID", 902)
    private val lastRunId = envInt("ISE_REPRO_LAST_RUN_ID", 903)
    private val seed = envInt("ISE_REPRO_SEED", 42)
    private val otherSeed = envInt("ISE_REPRO_OTHER_SEED", 43)
    private val agentNames = (1..8).map { "agent$it" }.toSet()
    private fun numberAsInt(value: String): Int = value.toDouble().toInt()

    private data class RunKey(val runId: Int, val seed: Int)
    private val first get() = RunKey(firstRunId, seed)
    private val middle get() = RunKey(middleRunId, otherSeed)
    private val last get() = RunKey(lastRunId, seed)

    private fun csvPath(name: String): Path {
        val module = Path.of("results", scenario, name)
        val root = Path.of("gametheory", "results", scenario, name)
        val path = if (Files.exists(module)) module else root
        require(Files.isRegularFile(path)) {
            "Missing $path. First execute three independent runs A-B-A as described above."
        }
        return path
    }

    private fun rows(name: String, key: RunKey, minimumColumns: Int): List<List<String>> =
        Files.readAllLines(csvPath(name))
            .asSequence()
            .filter { it.isNotBlank() }
            .map { line -> line.split(',').map(String::trim) }
            .filter { it.size >= 2 && it[0].toDoubleOrNull() != null }
            .filter { numberAsInt(it[0]) == key.runId && numberAsInt(it[1]) == key.seed }
            .map { columns ->
                require(columns.size >= minimumColumns) {
                    "Malformed $name for runId=${key.runId}, seed=${key.seed}: $columns"
                }
                columns
            }
            .toList()

    private fun validateComplete(key: RunKey) {
        val rounds = rows("rounds.csv", key, 7)
        val agents = rows("agents.csv", key, 9)
        assertEquals((1..expectedRounds).toList(), rounds.map { numberAsInt(it[2]) }.sorted(),
            "Missing or duplicate round for $key")
        assertEquals(expectedRounds * 8, agents.size, "Missing/extra agent rows for $key")

        val byRound = agents.groupBy { numberAsInt(it[2]) }
        for (round in 1..expectedRounds) {
            val group = byRound[round].orEmpty()
            assertEquals(8, group.size, "Expected 8 agent observations for $key round $round")
            assertEquals(agentNames, group.map { it[3] }.toSet(),
                "Missing/duplicate agent identity for $key round $round")
            assertTrue(group.all { it[5].toDouble() in 0.0..10.0 },
                "Illegal bid in $key round $round")
        }
    }

    private fun normalized(name: String, key: RunKey, columns: Int): List<String> =
        rows(name, key, columns)
            .map { it.drop(2).joinToString(",") } // drop run ID and seed only
            .sorted() // independent of asynchronous CSV append order

    @Test
    fun `three independent runs have complete disjoint observations`() {
        assertEquals(3, setOf(firstRunId, middleRunId, lastRunId).size,
            "Use distinct run IDs for A, B, and A again")
        assertTrue(seed != otherSeed, "B must use a different seed")
        for (key in listOf(first, middle, last)) validateComplete(key)
    }

    @Test
    fun `same seeded run is reproducible after a different run`() {
        assertEquals(3, setOf(firstRunId, middleRunId, lastRunId).size)
        validateComplete(first)
        validateComplete(middle)
        validateComplete(last)
        assertEquals(normalized("rounds.csv", first, 7), normalized("rounds.csv", last, 7),
            "Collective outcomes changed after running another seed")
        assertEquals(normalized("agents.csv", first, 9), normalized("agents.csv", last, 9),
            "Individual strategies, bids, or payoffs changed after another run")
        if (scenario == "no_comm") {
            assertEquals(normalized("strategies.csv", first, 9), normalized("strategies.csv", last, 9),
                "Strategy evaluations changed after running another seed")
        }
    }
}