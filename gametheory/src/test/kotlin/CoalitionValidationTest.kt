package simulation

import strips.SimulationConfig
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import kotlin.math.abs

/**
 * Post-run validation of the FIXED coalition scenario (FR4, NFR5).
 *
 * Run the coalition scenario first. Required CSVs:
 *   results/coalition/rounds.csv
 *   results/coalition/agents.csv
 *   results/coalition/coalitions.csv (optional if no links formed)
 *
 * Defaults: runId=3, seed=42, rounds=100.
 * Override with ISE_VALIDATION_RUN_ID, ISE_VALIDATION_SEED,
 * and ISE_VALIDATION_ROUNDS (same settings as the other post-run tests).
 *
 * The no-partner test is SKIPPED if that run had no agent without partners;
 * the trust-threshold test is SKIPPED if no coalition links formed.
 * For report evidence, choose seed(s) that exercise BOTH cases and ensure
 * these tests actually EXECUTE, not just appear as skipped.
 *
 * Example:
 *   ./gradlew :gametheory:test \
 *     --tests 'simulation.CoalitionValidationTest' --rerun-tasks
 */
class CoalitionValidationTest {
    private fun envInt(name: String, default: Int): Int =
        System.getenv(name)?.let { it.toIntOrNull() ?: error("$name must be an integer") }
            ?: default

    // must match data from config properties
    private val runId = envInt("ISE_VALIDATION_RUN_ID", 3)
    private val seed = envInt("ISE_VALIDATION_SEED", 42)
    private val expectedRounds = envInt("ISE_VALIDATION_ROUNDS", 100).also { require(it > 0) }
    private val coalitionInterval get() = SimulationConfig.communicationInterval
    private val trustThreshold get() = SimulationConfig.trustThreshold
    private val bidThreshold get() = SimulationConfig.bidThreshold
    private val maxPeers get() = SimulationConfig.maxPeers
    private val eps = 1e-6
    private val names = (1..SimulationConfig.agentCount).map { "agent$it" }.toSet()
    private fun numberAsInt(value: String): Int = value.toDouble().toInt()

    private data class Link(
        val round: Int, val agent: String, val peer: String,
        val agentBid: Double, val peerBid: Double,
        val agentTrust: Double, val peerTrust: Double
    )

    private fun csvPath(name: String, required: Boolean): Path? {
        val module = Path.of("results", "coalition", name)
        val root = Path.of("gametheory", "results", "coalition", name)
        val path = if (Files.exists(module)) module else root
        if (!Files.isRegularFile(path)) {
            require(!required) { "Missing $path. Run the coalition simulation first." }
            return null
        }
        return path
    }

    private fun rows(name: String, required: Boolean = true): List<List<String>> {
        val path = csvPath(name, required) ?: return emptyList()
        return Files.readAllLines(path)
            .asSequence()
            .filter { it.isNotBlank() }
            .map { line -> line.split(',').map(String::trim) }
            .filter { it.size >= 2 && it[0].toDoubleOrNull() != null }
            .filter { numberAsInt(it[0]) == runId && numberAsInt(it[1]) == seed }
            .toList()
    }

    private fun links(): List<Link> = rows("coalitions.csv", required = false).map { r ->
        require(r.size >= 9) { "Expected nine columns in coalitions.csv, got: $r" }
        Link(numberAsInt(r[2]), r[3].trim('"', '\''), r[4].trim('"', '\''),
            r[5].toDouble(), r[6].toDouble(), r[7].toDouble(), r[8].toDouble())
    }

    private fun checkCompleteRoundRecords(): Map<Int, Map<String, Double>> {
        val rounds = rows("rounds.csv")
        assertEquals((1..expectedRounds).toList(), rounds.map { numberAsInt(it[2]) }.sorted(),
            "Missing/duplicate coalition rounds")
        val agents = rows("agents.csv")
        assertEquals(expectedRounds * SimulationConfig.agentCount, agents.size, "Incomplete agent results")
        val byRound = agents.groupBy { numberAsInt(it[2]) }
        return (1..expectedRounds).associateWith { round ->
            val observations = byRound[round].orEmpty()
            assertEquals(SimulationConfig.agentCount, observations.size,
                "Missing/duplicated agent rows at round $round")
            assertEquals(names, observations.map { it[3].trim('"', '\'') }.toSet(),
                "Incorrect agent identities at round $round")
            observations.associate { it[3].trim('"', '\'') to it[5].toDouble() }
        }
    }

    @Test
    fun `mutual links obey both trust thresholds bid similarity and peer limit`() {
        val bids = checkCompleteRoundRecords()
        val recorded = links()
        assumeTrue(recorded.isNotEmpty(),
            "No coalition link in this run; choose a seed with coalition formation")

        val keys = recorded.map { Triple(it.round, it.agent, it.peer) }
        assertEquals(keys.size, keys.toSet().size, "Duplicate directed coalition link")
        val keySet = keys.toSet()
        for (link in recorded) {
            assertTrue(link.round in 1..expectedRounds && link.round % coalitionInterval == 0,
                "Coalition formed outside a coalition exchange round: $link")
            assertTrue(link.agent in names && link.peer in names && link.agent != link.peer,
                "Invalid or self-referential coalition link: $link")
            assertTrue(link.agentTrust in 0.0..1.0 && link.peerTrust in 0.0..1.0,
                "Trust outside [0,1] for $link")
            assertTrue(link.agentTrust + eps >= trustThreshold,
                "Agent's trust below $trustThreshold: $link")
            assertTrue(link.peerTrust + eps >= trustThreshold,
                "Peer's reciprocal trust below $trustThreshold: $link")
            assertTrue(abs(link.agentBid - link.peerBid) <= bidThreshold + eps,
                "Bid similarity threshold violated: $link")
            assertEquals(bids.getValue(link.round).getValue(link.agent), link.agentBid, eps)
            assertEquals(bids.getValue(link.round).getValue(link.peer), link.peerBid, eps)
            assertTrue(Triple(link.round, link.peer, link.agent) in keySet,
                "Non-mutual coalition link $link")
        }
        for ((agentRound, group) in recorded.groupBy { it.round to it.agent }) {
            assertTrue(group.size <= maxPeers,
                "Exceeded $maxPeers coalition partners at $agentRound")
        }
    }

    @Test
    fun `agents with no coalition partners still reach the next round`() {
        val bids = checkCompleteRoundRecords()
        val linked = links().map { it.round to it.agent }.toSet()
        val noPartner = (1..expectedRounds)
            .filter { it % coalitionInterval == 0 }
            .flatMap { round -> names.filter { (round to it) !in linked }.map { round to it } }
        assumeTrue(noPartner.isNotEmpty(),
            "No agent without coalition partners in this run; use another seed")

        for ((round, agent) in noPartner) {
            assertTrue(agent in bids.getValue(round), "Agent $agent missing in round $round")
            if (round < expectedRounds) {
                assertTrue(agent in bids.getValue(round + 1),
                    "Agent $agent stalled after having no coalition partners in round $round")
            }
        }
        println("Observed ${noPartner.size} no-partner agent-round cases")
    }
}