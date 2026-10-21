package simulation
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.Test
import java.nio.file.Files
import java.nio.file.Path
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Post-run validation of the ISE investing simulation.
 *
 * Run a fresh MAS simulation first, writing to results/adaptive/.
 * The default run ID, seed and number of rounds match main_planner.asl.
 *
 * Required CSV files: rounds.csv, agents.csv, modes.csv, decisions.csv.
 * Protocol CSVs: central_choices.csv, decentralized_suggestions.csv,
 * decentralized_choices.csv, coalition_links.csv, coalition_choices.csv.
 * The latter two may be absent if this run forms no coalition links.
 */
class InterventionValidationTest {
    private val runId = 3
    private val seed = 42
    private val expectedRounds = 300

    // Must match main_planner.asl and the agent's communication settings.
    private val minimumModeDuration = 5
    private val requiredOptimalStreak = 3
    private val communicationInterval = 5
    private val eps = 1e-6
    private val agentsExpected = (1..8).map { "agent$it" }.toSet()
    private val validModes = setOf("none", "centralized", "decentralized", "coalition")
    private val validDecisions = validModes + "keep"

    private data class RoundRow(
        val round: Int, val total: Double, val average: Double,
        val rent: Double, val rentPct: Double
    )
    private data class AgentRow(
        val round: Int, val agent: String, val strategy: String, val bid: Double,
        val market1: Double, val market2: Double, val payoff: Double
    )
    private data class DecisionRow(
        val round: Int, val current: String, val proposed: String,
        val applied: String, val age: Int, val optimalStreak: Int
    )
    private data class Choice(val round: Int, val agent: String, val bid: Double)
    private data class Link(val round: Int, val agent: String, val peer: String)
    private data class Suggestion(
        val round: Int, val receiver: String, val sender: String, val bid: Double
    )

    private fun number(value: String) = value.toDouble()
    private fun integer(value: String) = number(value).toInt()
    private fun atom(value: String) = value.trim().trim('"', '\'')

    private fun csv(filename: String, required: Boolean = true): List<List<String>> {
        // Gradle may run tests with gametheory/ or the repository root as working dir.
        val module = Path.of("results", "adaptive", filename)
        val root = Path.of("gametheory", "results", "adaptive", filename)
        val path = if (Files.exists(module)) module else root
        if (!Files.exists(path)) {
            if (!required) return emptyList()
            error("Missing $path. Run the simulation with logging enabled first.")
        }
        return Files.readAllLines(path)
            .filter { it.isNotBlank() }
            .map { line -> line.split(',').map { it.trim() } }
            .filter { it.size >= 3 && it[0].toDoubleOrNull() != null }
            .filter { integer(it[0]) == runId && integer(it[1]) == seed }
    }

    private fun rounds() = csv("rounds.csv").map {
        require(it.size >= 7) { "Bad rounds.csv row: $it" }
        RoundRow(integer(it[2]), number(it[3]), number(it[4]), number(it[5]), number(it[6]))
    }

    private fun agents() = csv("agents.csv").map {
        require(it.size >= 9) { "Bad agents.csv row: $it" }
        AgentRow(integer(it[2]), atom(it[3]), atom(it[4]), number(it[5]),
            number(it[6]), number(it[7]), number(it[8]))
    }

    private fun modes(): Map<Int, String> {
        val entries = csv("modes.csv").map {
            require(it.size >= 4) { "Bad modes.csv row: $it" }
            integer(it[2]) to atom(it[3])
        }
        assertEquals(entries.size, entries.map { it.first }.toSet().size,
            "Duplicate modes.csv rows. Clean CSV output before rerunning the same run ID/seed")
        return entries.toMap()
    }

    private fun decisions(): Map<Int, DecisionRow> {
        val entries = csv("decisions.csv").map {
            require(it.size >= 8) { "Bad decisions.csv row: $it" }
            DecisionRow(integer(it[2]), atom(it[3]), atom(it[4]), atom(it[5]),
                integer(it[6]), integer(it[7]))
        }
        assertEquals(entries.size, entries.map { it.round }.toSet().size,
            "Duplicate decisions.csv rows")
        return entries.associateBy { it.round }
    }

    private fun centralChoices() = csv("central_choices.csv", required = false).map {
        require(it.size >= 4)
        Choice(integer(it[2]), "planner", number(it[3]))
    }

    private fun decentralizedSuggestions() = csv("decentralized_suggestions.csv", required = false).map {
        require(it.size >= 6)
        Suggestion(integer(it[2]), atom(it[3]), atom(it[4]), number(it[5]))
    }

    private fun decentralizedChoices() = csv("decentralized_choices.csv", required = false).map {
        require(it.size >= 5)
        Choice(integer(it[2]), atom(it[3]), number(it[4]))
    }

    private fun coalitionLinks() = csv("coalition_links.csv", required = false).map {
        require(it.size >= 5)
        Link(integer(it[2]), atom(it[3]), atom(it[4]))
    }

    private fun coalitionChoices() = csv("coalition_choices.csv", required = false).map {
        require(it.size >= 5)
        Choice(integer(it[2]), atom(it[3]), number(it[4]))
    }

    private fun optimal(round: RoundRow): Boolean {
        val error = (round.total - 36.0) / 36.0
        return error in -0.15..0.15
    }

    private fun effectiveIntervention(
        current: String, proposed: String, age: Int, optimalStreak: Int
    ): String = when {
        current != "none" && proposed != "keep" && age < minimumModeDuration -> "keep"
        current != "none" && proposed == "none" && optimalStreak < requiredOptimalStreak -> "keep"
        else -> proposed
    }

    @Test
    fun `all 300 rounds contain eight valid bids and correct payoffs`() {
        val rounds = rounds()
        val agents = agents()
        assertEquals((1..expectedRounds).toList(), rounds.map { it.round }.sorted(),
            "Missing or duplicated rounds")
        assertEquals(expectedRounds * 8, agents.size, "Missing or duplicated agent rows")

        val byRound = agents.groupBy { it.round }
        for (row in rounds) {
            val group = byRound[row.round].orEmpty()
            assertEquals(8, group.size, "Expected eight bids in round ${row.round}")
            assertEquals(agentsExpected, group.map { it.agent }.toSet(),
                "Wrong set of agents in round ${row.round}")
            assertTrue(group.all { it.bid in 0.0..10.0 },
                "Out-of-bounds bid in round ${row.round}")
            assertEquals(group.sumOf { it.bid }, row.total, eps,
                "Incorrect group investment in round ${row.round}")
            assertEquals(row.total / 8.0, row.average, eps)
            val rent = row.total * (23.0 - 0.25 * row.total) - 5.0 * row.total
            assertEquals(rent, row.rent, eps, "Incorrect group rent in round ${row.round}")
            assertEquals(100.0 * rent / 324.0, row.rentPct, eps)
            for (a in group) {
                val market1 = 5.0 * (10.0 - a.bid)
                val market2 = a.bid * (23.0 - 0.25 * row.total)
                assertEquals(market1, a.market1, eps)
                assertEquals(market2, a.market2, eps)
                assertEquals(market1 + market2, a.payoff, eps)
            }
        }
    }

    @Test
    fun `five round minimum and three optimal round rule enforce every decision`() {
        val modes = modes()
        val decisions = decisions()
        val rounds = rounds().associateBy { it.round }
        assertEquals((1..expectedRounds).toSet(), modes.keys, "Modes log incomplete")
        assertEquals((1..expectedRounds).toSet(), decisions.keys, "Decisions log incomplete")
        assertEquals("none", modes[1], "Expected initial intervention to be none")

        var enteredModeAtRound = 1
        var streak = 0
        for (r in 1..expectedRounds) {
            val current = modes.getValue(r)
            val decision = decisions.getValue(r)
            assertTrue(current in validModes, "Unknown mode '$current' at round $r")
            assertTrue(decision.proposed in validDecisions,
                "Unknown STRIPS proposal '${decision.proposed}' at round $r")
            assertTrue(decision.applied in validDecisions,
                "Unknown enforced intervention '${decision.applied}' at round $r")
            assertEquals(current, decision.current, "Decision uses wrong mode at round $r")

            if (r > 1 && current != modes.getValue(r - 1)) enteredModeAtRound = r
            val independentlyComputedAge = r - enteredModeAtRound + 1
            streak = if (optimal(rounds.getValue(r))) streak + 1 else 0

            assertEquals(independentlyComputedAge, decision.age,
                "Incorrect current mode duration at round $r")
            assertEquals(streak, decision.optimalStreak,
                "Incorrect consecutive-optimal counter at round $r")
            val expected = effectiveIntervention(current, decision.proposed,
                independentlyComputedAge, streak)
            assertEquals(expected, decision.applied,
                "Incorrect minimum-duration / optimal-streak gating at round $r")

            if (r < expectedRounds) {
                val expectedNextMode = if (decision.applied == "keep") current else decision.applied
                assertEquals(expectedNextMode, modes.getValue(r + 1),
                    "Wrong next-round intervention after round $r")
                if (current != "none" && expectedNextMode != current) {
                    assertTrue(independentlyComputedAge >= minimumModeDuration,
                        "Switched away from $current before $minimumModeDuration rounds at round $r")
                }
                if (current != "none" && expectedNextMode == "none") {
                    assertTrue(streak >= requiredOptimalStreak,
                        "Disabled $current without $requiredOptimalStreak optimal rounds at round $r")
                }
            }
        }
    }

    @Test
    fun `minimum duration and optimal streak boundary cases`() {
        assertEquals("keep", effectiveIntervention("centralized", "decentralized", 4, 0))
        assertEquals("decentralized", effectiveIntervention("centralized", "decentralized", 5, 0))
        assertEquals("keep", effectiveIntervention("coalition", "none", 5, 2))
        assertEquals("none", effectiveIntervention("coalition", "none", 5, 3))
        assertEquals("keep", effectiveIntervention("centralized", "none", 4, 3))
        // No lock on 'none': an intervention can begin at any round.
        assertEquals("centralized", effectiveIntervention("none", "centralized", 1, 0))
        assertEquals("keep", effectiveIntervention("none", "keep", 1, 1))
    }

    @Test
    fun `STRIPS proposes coherent intervention from the symbolic state`() {
        val modes = modes()
        val decisions = decisions()
        val rounds = rounds().associateBy { it.round }
        val byRound = agents().groupBy { it.round }
        for (r in 1..expectedRounds) {
            val current = modes.getValue(r)
            val total = rounds.getValue(r).total
            val error = (total - 36.0) / 36.0
            val bids = byRound.getValue(r).map { it.bid }
            val mean = bids.average()
            val sd = sqrt(bids.map { (it - mean) * (it - mean) }.average())
            val expectedTarget = when {
                error > 0.15 -> "centralized"
                error >= -0.15 -> "none"
                sd <= 2.0 -> "decentralized"
                current == "decentralized" || current == "coalition" -> "coalition"
                else -> "decentralized" // first preparation step toward a coalition
            }
            val proposed = decisions.getValue(r).proposed
            if (expectedTarget == current) {
                // Some solver implementations normalize 'maintain_mode' to the mode itself.
                assertTrue(proposed == "keep" || proposed == current,
                    "Unexpected STRIPS maintenance proposal '$proposed' in round $r")
            } else {
                assertEquals(expectedTarget, proposed,
                    "Unexpected STRIPS proposal in round $r: error=$error, sd=$sd, current=$current")
            }
        }
    }

    @Test
    fun `centralized bid is obeyed by all eight agents on the following round`() {
        val modes = modes()
        val choices = centralChoices().groupBy { it.round }
        val agents = agents().groupBy { it.round }
        var validated = 0
        for (r in 1 until expectedRounds) {
            if (modes[r] != "centralized" || modes[r + 1] != "centralized") continue
            val chosen = choices[r].orEmpty()
            assertEquals(1, chosen.size, "Missing or multiple central selections for round $r")
            for (a in agents.getValue(r + 1)) {
                assertEquals(chosen.single().bid, a.bid, eps,
                    "${a.agent} did not follow the central bid for round ${r + 1}")
                assertEquals("central_imposed", a.strategy,
                    "${a.agent} did not report central execution in round ${r + 1}")
            }
            validated++
        }
        assumeTrue(validated > 0, "This run never contained two consecutive centralized rounds")
    }

    @Test
    fun `decentralized communication receives seven proposals and chooses highest local payoff`() {
        val modes = modes()
        val suggestions = decentralizedSuggestions().groupBy { it.round to it.receiver }
        val choices = decentralizedChoices().groupBy { it.round to it.agent }
        val agents = agents().groupBy { it.round }
            .mapValues { (_, group) -> group.associateBy { it.agent } }
        val totals = rounds().associateBy { it.round }
        var validated = 0

        for (r in 1..expectedRounds) {
            if (r % communicationInterval != 0 || modes[r] != "decentralized") continue
            for (agent in agentsExpected) {
                val received = suggestions[r to agent].orEmpty()
                assertEquals(7, received.size,
                    "$agent must receive seven peer proposals in decentralized round $r")
                assertEquals(agentsExpected - agent, received.map { it.sender }.toSet(),
                    "$agent has missing or duplicate decentralized senders in round $r")
                assertTrue(received.all { it.receiver == agent && it.bid in 0.0..10.0 })

                val chosen = choices[r to agent].orEmpty()
                assertEquals(1, chosen.size, "Expected one decentralized choice for $agent, round $r")
                val chosenBid = chosen.single().bid
                assertTrue(received.any { abs(it.bid - chosenBid) <= eps },
                    "Decentralized $agent chose a bid not proposed by a peer in round $r")

                val myBid = agents.getValue(r).getValue(agent).bid
                val groupTotal = totals.getValue(r).total
                fun payoff(bid: Double): Double {
                    val counterTotal = groupTotal - myBid + bid
                    return 5.0 * (10.0 - bid) + bid * (23.0 - 0.25 * counterTotal)
                }
                assertEquals(received.maxOf { payoff(it.bid) }, payoff(chosenBid), eps,
                    "Decentralized $agent did not choose its highest-payoff suggestion in round $r")

                if (r < expectedRounds && modes[r + 1] == "decentralized") {
                    val next = agents.getValue(r + 1).getValue(agent)
                    assertTrue(next.strategy.startsWith("comm(") && next.strategy.endsWith(")"),
                        "$agent did not install a communicated strategy after round $r")
                    assertEquals(chosenBid, next.bid, eps,
                        "$agent did not play its chosen decentralized bid in round ${r + 1}")
                }
            }
            validated++
        }
        assumeTrue(validated > 0, "No decentralized communication round in this run")
    }

    @Test
    fun `coalition links are mutual and bids maximize payoff among peer suggestions`() {
        val modes = modes()
        val links = coalitionLinks()
        val choices = coalitionChoices()
        val byRound = agents().groupBy { it.round }
            .mapValues { (_, group) -> group.associateBy { it.agent } }
        val totals = rounds().associateBy { it.round }
        val uniqueLinks = links.map { Triple(it.round, it.agent, it.peer) }.toSet()
        assertEquals(links.size, uniqueLinks.size, "Duplicate coalition link")

        for (link in links) {
            assertEquals("coalition", modes[link.round], "Coalition link formed in non-coalition mode")
            assertEquals(0, link.round % communicationInterval, "Coalition link outside exchange round")
            assertTrue(link.agent != link.peer, "Coalition self-link")
            assertTrue(Triple(link.round, link.peer, link.agent) in uniqueLinks,
                "Non-mutual coalition link ${link.agent} -> ${link.peer} in round ${link.round}")
            val participants = byRound.getValue(link.round)
            assertTrue(abs(participants.getValue(link.agent).bid - participants.getValue(link.peer).bid)
                    <= 2.0 + eps, "Coalition bid-distance rule violated at round ${link.round}")
        }
        for ((roundAndAgent, linksForAgent) in links.groupBy { it.round to it.agent }) {
            assertTrue(linksForAgent.size <= 3,
                "Maximum of three coalition peers exceeded by $roundAndAgent")
        }

        val choiceGroups = choices.groupBy { it.round to it.agent }
        val linkGroups = links.groupBy { it.round to it.agent }
        assertEquals(linkGroups.keys, choiceGroups.keys,
            "Every agent with coalition peers must choose a bid, and only such agents do so")
        for ((key, outgoingLinks) in linkGroups) {
            val (r, agent) = key
            val recorded = choiceGroups.getValue(key)
            assertEquals(1, recorded.size, "Expected one coalition bid selection for $key")
            val chosenBid = recorded.single().bid
            val peers = byRound.getValue(r)
            val oldBid = peers.getValue(agent).bid
            val proposals = (listOf(oldBid) + outgoingLinks.map { peers.getValue(it.peer).bid }).toSet()
            assertTrue(proposals.any { abs(it - chosenBid) <= eps },
                "Coalition $agent in round $r chose a bid nobody proposed")

            fun payoff(bid: Double): Double {
                val total = totals.getValue(r).total - oldBid + bid
                return 5.0 * (10.0 - bid) + bid * (23.0 - 0.25 * total)
            }
            assertEquals(proposals.maxOf { payoff(it) }, payoff(chosenBid), eps,
                "Coalition $agent did not choose the highest-payoff proposed bid")
            if (r < expectedRounds && modes[r + 1] == "coalition") {
                val next = byRound.getValue(r + 1).getValue(agent)
                assertEquals(chosenBid, next.bid, eps,
                    "Coalition $agent did not follow its chosen bid in round ${r + 1}")
                assertTrue(next.strategy.startsWith("comm(") && next.strategy.endsWith(")"),
                    "Coalition bid for $agent was not installed as a communication strategy")
            }
        }
        assumeTrue(links.isNotEmpty(), "This run formed no coalitions; use another seed to exercise them")
    }
}

