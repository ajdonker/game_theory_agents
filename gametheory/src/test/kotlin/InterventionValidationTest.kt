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
 * Post-run validation of the ISE investing simulation.
 *
 * Run a fresh MAS simulation first, writing to results/adaptive/.
 * Select the run being validated with ISE_VALIDATION_RUN_ID and
 * ISE_VALIDATION_SEED (defaults: 3 and 42). Set ISE_VALIDATION_ROUNDS
 * to the number of rounds requested in the simulation (default: 300).
 * Each count is explicit so an incomplete run cannot pass by inference.
 *
 * Required CSV files: rounds.csv, agents.csv, modes.csv; decisions.csv is
 * required when the run reaches the first adaptive planning round.
 * Protocol CSVs: central_choices.csv, decentralized_suggestions.csv,
 * decentralized_choices.csv, coalition_links.csv, coalition_choices.csv.
 * The latter two may be absent if this run forms no coalition links.
 */
class InterventionValidationTest {
    private fun configuredInt(property: String, environment: String, default: Int): Int {
        val raw = System.getProperty(property) ?: System.getenv(environment) ?: return default
        return raw.toIntOrNull()
            ?: error("Invalid $property / $environment: '$raw' (expected an integer)")
    }
    // must match data from config properties OR injected from GUI
    private val runId = configuredInt("ise.validation.runId", "ISE_VALIDATION_RUN_ID", 3)
    private val seed = configuredInt("ise.validation.seed", "ISE_VALIDATION_SEED", 42)
    private val expectedRounds = configuredInt("ise.validation.rounds", "ISE_VALIDATION_ROUNDS", 300)
        .also { require(it > 0) { "Expected rounds must be positive" } }

    private val ENDOWMENT get() = SimulationConfig.endowment
    private val MARKET1_RETURN get() = SimulationConfig.market1Return
    private val CPR_A get() = SimulationConfig.cprA
    private val CPR_B get() = SimulationConfig.cprB
    private val OPTIMUM get() = SimulationConfig.optimum
    private val OPTIMAL_RENT get() = SimulationConfig.optimalRent
    private val OPTIMAL_TOLERANCE get() = SimulationConfig.optimalTolerance
    private val AGENT_COUNT get() = SimulationConfig.agentCount
    private val planningStartRound get() = SimulationConfig.explorationRounds
    private val minimumModeDuration get() = SimulationConfig.minDuration
    private val requiredOptimalCount get() = SimulationConfig.minOptimalRounds
    private val optimalityWindow get() = SimulationConfig.optimalityWindow
    private val communicationInterval get() = SimulationConfig.communicationInterval
    private val BID_THRESHOLD get() = SimulationConfig.bidThreshold
    private val MAX_PEERS get() = SimulationConfig.maxPeers
    private val eps = 1e-6
    private val agentsExpected = (1..AGENT_COUNT).map { "agent$it" }.toSet()
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
        val applied: String, val age: Int, val optimalCount: Int
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
        val entries = csv("decisions.csv", required = expectedRounds >= planningStartRound).map {
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
        val error = (round.total - OPTIMUM) / OPTIMUM
        return error in -OPTIMAL_TOLERANCE..OPTIMAL_TOLERANCE
    }

    private fun effectiveIntervention(
        current: String, proposed: String, age: Int, optimalCount: Int
    ): String = when {
        current != "none" && proposed != "keep" && age < minimumModeDuration -> "keep"
        current != "none" && proposed == "none" && optimalCount < requiredOptimalCount -> "keep"
        else -> proposed
    }

    @Test
    fun `all configured rounds contain valid bids and correct payoffs`() {
        val rounds = rounds()
        val agents = agents()
        assertEquals((1..expectedRounds).toList(), rounds.map { it.round }.sorted(),
            "Missing or duplicated rounds")
        assertEquals(expectedRounds * AGENT_COUNT, agents.size, "Missing or duplicated agent rows")

        val byRound = agents.groupBy { it.round }
        for (row in rounds) {
            val group = byRound[row.round].orEmpty()
            assertEquals(AGENT_COUNT, group.size, "Expected $AGENT_COUNT bids in round ${row.round}")
            assertEquals(agentsExpected, group.map { it.agent }.toSet(),
                "Wrong set of agents in round ${row.round}")
            assertTrue(group.all { it.bid in 0.0..ENDOWMENT },
                "Out-of-bounds bid in round ${row.round}")
            assertEquals(group.sumOf { it.bid }, row.total, eps,
                "Incorrect group investment in round ${row.round}")
            assertEquals(row.total / AGENT_COUNT, row.average, eps)
            val rent = row.total * (CPR_A - CPR_B * row.total) - MARKET1_RETURN * row.total
            assertEquals(rent, row.rent, eps, "Incorrect group rent in round ${row.round}")
            assertEquals(100.0 * rent / OPTIMAL_RENT, row.rentPct, eps)
            for (a in group) {
                val market1 = MARKET1_RETURN * (ENDOWMENT - a.bid)
                val market2 = a.bid * (CPR_A - CPR_B * row.total)
                assertEquals(market1, a.market1, eps)
                assertEquals(market2, a.market2, eps)
                assertEquals(market1 + market2, a.payoff, eps)
            }
        }
    }

    @Test
    fun `configured mode duration and optimal-round count gate interventions`() {
        val modes = modes()
        val decisions = decisions()
        val roundsByNumber = rounds().associateBy { it.round }

        assertEquals((1..expectedRounds).toSet(), modes.keys, "Modes log incomplete")
        val planningRounds = (planningStartRound..expectedRounds).toSet()
        assertEquals(planningRounds, decisions.keys,
            "Decisions must be logged exactly from round $planningStartRound onward")
        assertEquals("none", modes[1], "Expected initial intervention to be none")

        var enteredModeAtRound = 1
        for (r in 1..expectedRounds) {
            val current = modes.getValue(r)
            assertTrue(current in validModes, "Unknown mode '$current' at round $r")
            if (r > 1 && current != modes.getValue(r - 1)) enteredModeAtRound = r

            // The first decision occurs at the end of the exploration period.
            if (r < planningStartRound) {
                assertEquals("none", current, "Intervention active during the initial grace period")
                continue
            }
            if (r == planningStartRound) {
                assertEquals("none", current, "The final exploration round must still be uncoordinated")
            }

            val decision = decisions.getValue(r)
            assertTrue(decision.proposed in validDecisions,
                "Unknown STRIPS proposal '${decision.proposed}' at round $r")
            assertTrue(decision.applied in validDecisions,
                "Unknown enforced intervention '${decision.applied}' at round $r")
            assertEquals(current, decision.current, "Decision uses wrong mode at round $r")

            val independentlyComputedAge = r - enteredModeAtRound + 1
            // Not a consecutive streak: count optimal investments in the configured window.
            val optimalCount = (maxOf(1, r - optimalityWindow + 1)..r)
                .count { optimal(roundsByNumber.getValue(it)) }
            assertEquals(independentlyComputedAge, decision.age,
                "Incorrect current mode duration at round $r")
            assertEquals(optimalCount, decision.optimalCount,
                "Incorrect number of optimal-investment rounds within the previous $optimalityWindow at round $r")
            val expected = effectiveIntervention(current, decision.proposed,
                independentlyComputedAge, optimalCount)
            assertEquals(expected, decision.applied,
                "Incorrect minimum-duration / optimal-round gating at round $r")

            if (r < expectedRounds) {
                val expectedNextMode = if (decision.applied == "keep") current else decision.applied
                assertEquals(expectedNextMode, modes.getValue(r + 1),
                    "Wrong next-round intervention after round $r")
                if (current != "none" && expectedNextMode != current) {
                    assertTrue(independentlyComputedAge >= minimumModeDuration,
                        "Switched away from $current before $minimumModeDuration rounds at round $r")
                }
                if (current != "none" && expectedNextMode == "none") {
                    assertTrue(optimalCount >= requiredOptimalCount,
                        "Disabled $current without $requiredOptimalCount optimal rounds in the configured window")
                }
            }
        }
    }

    @Test
    fun `configured mode duration and optimal-round boundary cases`() {
        assertEquals("keep", effectiveIntervention("centralized", "decentralized",
            minimumModeDuration - 1, 0))
        assertEquals("decentralized", effectiveIntervention("centralized", "decentralized",
            minimumModeDuration, 0))
        assertEquals("keep", effectiveIntervention("coalition", "none",
            minimumModeDuration, requiredOptimalCount - 1))
        assertEquals("none", effectiveIntervention("coalition", "none",
            minimumModeDuration, requiredOptimalCount))
        assertEquals("keep", effectiveIntervention("centralized", "none",
            minimumModeDuration - 1, requiredOptimalCount))
        // No minimum duration applies when starting from no intervention.
        assertEquals("centralized", effectiveIntervention("none", "centralized", 1, 0))
        assertEquals("keep", effectiveIntervention("none", "keep", 1, 1))
    }

    @Test
    fun `STRIPS proposals respect clear no-intervention investment thresholds`() {
        val modes = modes()
        val decisions = decisions()
        val roundRows = rounds().associateBy { it.round }
        // Other modes also depend on recent intervention performance (e.g.
        // centralized_ineffective and decentralized_crater); a simple investment
        // threshold cannot predict every proposal in those modes.
        var checked = 0
        for ((r, decision) in decisions) {
            if (modes.getValue(r) != "none") continue
            val total = roundRows.getValue(r).total
            val error = (total - OPTIMUM) / OPTIMUM
            val expected = when {
                error > OPTIMAL_TOLERANCE -> "centralized"
                error < -OPTIMAL_TOLERANCE -> "decentralized" // May be preparation for coalition mode.
                else -> "keep"
            }
            assertEquals(expected, decision.proposed,
                "Unexpected STRIPS proposal in no-intervention round $r (error=$error)")
            checked++
        }
        assumeTrue(checked > 0, "No STRIPS decisions while mode was 'none' in this run")
    }

    @Test
    fun `centralized selections are logged without assuming agents cannot deviate`() {
        val modes = modes()
        val choices = centralChoices()
        val eligibleRounds = (planningStartRound..expectedRounds)
            .filter { r -> r % communicationInterval == 0 && modes[r] == "centralized" }
            .toSet()

        val expectedSelectionRounds = modes
            .filterValues { it == "centralized" }
            .keys

        val actualSelectionRounds = choices.map { it.round }

        assertEquals(
            actualSelectionRounds.size,
            actualSelectionRounds.toSet().size,
            "Multiple centralized choices recorded for the same round"
        )

        assertEquals(
            expectedSelectionRounds,
            actualSelectionRounds.toSet(),
            "Missing or unexpected centralized selections"
        )

        // Agents may deviate from the selected bid. For that reason, requiring
        // all eight to play central_imposed in r+1 is not a valid assertion.
        assumeTrue(eligibleRounds.isNotEmpty(), "No centralized communication round in this run")
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
                assertEquals(AGENT_COUNT - 1, received.size,
                    "$agent must receive proposals from every peer in decentralized round $r")
                assertEquals(agentsExpected - agent, received.map { it.sender }.toSet(),
                    "$agent has missing or duplicate decentralized senders in round $r")
                assertTrue(received.all { it.receiver == agent && it.bid in 0.0..ENDOWMENT })

                val chosen = choices[r to agent].orEmpty()
                assertEquals(1, chosen.size, "Expected one decentralized choice for $agent, round $r")
                val chosenBid = chosen.single().bid
                assertTrue(received.any { abs(it.bid - chosenBid) <= eps },
                    "Decentralized $agent chose a bid not proposed by a peer in round $r")

                val myBid = agents.getValue(r).getValue(agent).bid
                val groupTotal = totals.getValue(r).total
                fun payoff(bid: Double): Double {
                    val counterTotal = groupTotal - myBid + bid
                    return MARKET1_RETURN * (ENDOWMENT - bid) +
                            bid * (CPR_A - CPR_B * counterTotal)
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
    fun `coalition links are mutual and communicated bids are valid`() {
        val modes = modes()
        val links = coalitionLinks()
        val choices = coalitionChoices()
        val byRound = agents().groupBy { it.round }
            .mapValues { (_, group) -> group.associateBy { it.agent } }
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
                    <= BID_THRESHOLD + eps,
                "Coalition bid-distance rule violated at round ${link.round}")
        }
        for ((roundAndAgent, linksForAgent) in links.groupBy { it.round to it.agent }) {
            assertTrue(linksForAgent.size <= MAX_PEERS,
                "Maximum of $MAX_PEERS coalition peers exceeded by $roundAndAgent")
        }

        val choiceGroups = choices.groupBy { it.round to it.agent }
        val linkGroups = links.groupBy { it.round to it.agent }
        assertEquals(linkGroups.keys, choiceGroups.keys,
            "Only agents with coalition peers should make a coalition bid choice")
        for ((key, _) in linkGroups) {
            val (r, agent) = key
            val recorded = choiceGroups.getValue(key)
            assertEquals(1, recorded.size, "Expected one coalition bid selection for $key")
            val chosenBid = recorded.single().bid
            assertTrue(chosenBid in 0.0..ENDOWMENT, "Illegal coalition choice for $key")

            // Peers send their highest-scoring candidate, not necessarily the bid
            // they actually played in round r. Comparing to played bids would
            // incorrectly reject valid choices. The received messages would need
            // to be logged to validate optimality among those suggestions.
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
