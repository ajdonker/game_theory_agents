package simulation

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import java.nio.file.Files
import java.nio.file.Path
import kotlin.math.abs

class InvestingSimulationValidationTest {

    companion object {
        private const val SEED = 42
        private const val EXPECTED_AGENTS = 8
        private const val EXPECTED_STRATEGIES_PER_AGENT = 4
        private const val EXPECTED_ROUNDS = 100

        private const val ENDOWMENT = 10.0
        private const val MARKET1_RETURN = 5.0
        private const val CPR_A = 23.0
        private const val CPR_B = 0.25

        private const val EPS = 0.000001
    }

    data class RoundRow(
    val runId: Int,
    val seed: Int,
    val round: Int,
    val totalBid: Double,
    val averageBid: Double,
    val groupRent: Double,
    val rentPct: Double
)

data class AgentRow(
    val runId: Int,
    val seed: Int,
    val round: Int,
    val agent: String,
    val strategy: String,
    val bid: Double,
    val market1: Double,
    val market2: Double,
    val payoff: Double
)

data class StrategyRow(
    val runId: Int,
    val seed: Int,
    val round: Int,
    val agent: String,
    val strategy: String,
    val candidateBid: Double,
    val counterfactualPayoff: Double,
    val sum: Double,
    val evaluations: Int
)

    private fun readLines(file: String): List<String> =
        Files.readAllLines(Path.of("results", file))
            .filter { it.isNotBlank() }

    private fun csvRows(
        file: String,
        expectedColumns: Int
    ): List<List<String>> =
        readLines(file).mapIndexed { index, line ->

            val columns = line.split(",")

            require(columns.size == expectedColumns) {
                "$file line ${index + 1}: expected $expectedColumns columns " +
                "but got ${columns.size}. Row: $line"
            }

            columns.map { it.trim() }
    }        
    private fun rounds(): List<RoundRow> =
    csvRows("rounds.csv", 7)
        .map { c ->
            RoundRow(
                runId = c[0].toInt(),
                seed = c[1].toInt(),
                round = c[2].toInt(),
                totalBid = c[3].toDouble(),
                averageBid = c[4].toDouble(),
                groupRent = c[5].toDouble(),
                rentPct = c[6].toDouble()
            )
        }
        .filter { it.seed == SEED }

    private fun agents(): List<AgentRow> =
        csvRows("agents.csv", 9)
            .map { c ->
                AgentRow(
                    runId = c[0].toInt(),
                    seed = c[1].toInt(),
                    round = c[2].toInt(),
                    agent = c[3],
                    strategy = c[4],
                    bid = c[5].toDouble(),
                    market1 = c[6].toDouble(),
                    market2 = c[7].toDouble(),
                    payoff = c[8].toDouble()
                )
            }
            .filter { it.seed == SEED }

    private fun strategies(): List<StrategyRow> =
    csvRows("strategies.csv", 9)
        .map { c ->
            StrategyRow(
                runId = c[0].toInt(),
                seed = c[1].toInt(),
                round = c[2].toInt(),
                agent = c[3],
                strategy = c[4],
                candidateBid = c[5].toDouble(),
                counterfactualPayoff = c[6].toDouble(),
                sum = c[7].toDouble(),
                evaluations = c[8].toInt()
            )
        }
        .filter { it.seed == SEED }

    @Test
    fun `simulation has eight agents and all expected rounds`() {
        val agentRows = agents()
        val roundRows = rounds()

        val names = agentRows.map { it.agent }.toSet()

        assertEquals(
            EXPECTED_AGENTS,
            names.size,
            "Simulation should contain exactly 8 agents"
        )

        val actualRounds = roundRows.map { it.round }.sorted()

        assertEquals(
            (1..EXPECTED_ROUNDS).toList(),
            actualRounds,
            "Rounds should run consecutively from 1 to $EXPECTED_ROUNDS"
        )
    }

    @Test
    fun `every round contains exactly eight agent observations`() {
        agents()
            .groupBy { it.round }
            .forEach { (round, rows) ->
                assertEquals(
                    EXPECTED_AGENTS,
                    rows.size,
                    "Round $round does not contain exactly 8 agent rows"
                )

                assertEquals(
                    EXPECTED_AGENTS,
                    rows.map { it.agent }.toSet().size,
                    "Round $round contains duplicate or missing agents"
                )
            }
    }

    @Test
    fun `each agent owns exactly four strategies`() {
        strategies()
            .groupBy { it.agent }
            .forEach { (agent, rows) ->

                val strategyPool =
                    rows.map { it.strategy }.toSet()

                assertEquals(
                    EXPECTED_STRATEGIES_PER_AGENT,
                    strategyPool.size,
                    "$agent should own exactly 4 strategies"
                )
            }
    }

    @Test
    fun `strategy pool remains constant for entire run`() {
        val strategyRows = strategies()

        strategyRows
            .groupBy { it.agent }
            .forEach { (agent, agentRows) ->

                val expectedPool =
                    agentRows
                        .filter { it.round == 1 }
                        .map { it.strategy }
                        .toSet()

                agentRows
                    .groupBy { it.round }
                    .forEach { (round, rows) ->

                        val pool =
                            rows.map { it.strategy }.toSet()

                        assertEquals(
                            expectedPool,
                            pool,
                            "$agent has a different strategy pool in round $round"
                        )
                    }
            }
    }

    @Test
    fun `every owned strategy is evaluated once per round`() {
        strategies()
            .groupBy { Pair(it.agent, it.round) }
            .forEach { (key, rows) ->

                assertEquals(
                    EXPECTED_STRATEGIES_PER_AGENT,
                    rows.size,
                    "${key.first}, round ${key.second}: expected 4 strategy evaluations"
                )

                assertEquals(
                    EXPECTED_STRATEGIES_PER_AGENT,
                    rows.map { it.strategy }.toSet().size,
                    "${key.first}, round ${key.second}: duplicate strategy evaluation"
                )
            }
    }

    @Test
    fun `all bids remain within legal bounds`() {
        agents().forEach {
            assertTrue(
                it.bid in 0.0..ENDOWMENT,
                "${it.agent} submitted illegal bid ${it.bid} in round ${it.round}"
            )
        }

        strategies().forEach {
            assertTrue(
                it.candidateBid in 0.0..ENDOWMENT,
                "${it.agent}/${it.strategy} generated illegal bid " +
                    "${it.candidateBid} in round ${it.round}"
            )
        }
    }

    @Test
    fun `group totals equal sum of individual bids`() {
        val roundMap = rounds().associateBy { it.round }

        agents()
            .groupBy { it.round }
            .forEach { (round, rows) ->

                val sum = rows.sumOf { it.bid }

                val recorded =
                    roundMap[round]
                        ?: error("Missing group row for round $round")

                assertEquals(
                    recorded.totalBid,
                    sum,
                    EPS,
                    "Group total does not equal sum of bids in round $round"
                )

                assertEquals(
                    recorded.totalBid / EXPECTED_AGENTS,
                    recorded.averageBid,
                    EPS,
                    "Incorrect group average in round $round"
                )
            }
    }

    @Test
    fun `individual payoff calculations are correct`() {
        val groupTotals =
            rounds().associate { it.round to it.totalBid }

        agents().forEach { row ->

            val total =
                groupTotals[row.round]
                    ?: error("Missing group total")

            val expectedM1 =
                MARKET1_RETURN * (ENDOWMENT - row.bid)

            val expectedM2 =
                row.bid * (CPR_A - CPR_B * total)

            val expectedPayoff =
                expectedM1 + expectedM2

            assertEquals(
                expectedM1,
                row.market1,
                EPS,
                "Wrong M1 payoff for ${row.agent}, round ${row.round}"
            )

            assertEquals(
                expectedM2,
                row.market2,
                EPS,
                "Wrong M2 payoff for ${row.agent}, round ${row.round}"
            )

            assertEquals(
                expectedPayoff,
                row.payoff,
                EPS,
                "Wrong total payoff for ${row.agent}, round ${row.round}"
            )
        }
    }

    @Test
    fun `rent calculations are correct`() {
        val optimalBid =
            (CPR_A - MARKET1_RETURN) /
                (2.0 * CPR_B)

        val optimalRent =
            optimalBid *
                (CPR_A - CPR_B * optimalBid) -
                MARKET1_RETURN * optimalBid

        assertEquals(
            36.0,
            optimalBid,
            EPS
        )
        
        rounds().forEach { row ->

            val expectedRent =
                row.totalBid *
                    (CPR_A - CPR_B * row.totalBid) -
                    MARKET1_RETURN * row.totalBid

            val expectedPct =
                100.0 * expectedRent / optimalRent

            assertEquals(
                expectedRent,
                row.groupRent,
                EPS,
                "Wrong rent in round ${row.round}"
            )

            assertEquals(
                expectedPct,
                row.rentPct,
                EPS,
                "Wrong rent percentage in round ${row.round}"
            )

            if (abs(row.totalBid - 36.0) < EPS) {
                assertEquals(
                    100.0,
                    row.rentPct,
                    EPS,
                    "Total bid 36 should produce 100% optimum rent"
                )
            }
        }
    }

    @Test
    fun `played strategy always belongs to agents strategy pool`() {
        val pools =
            strategies()
                .groupBy { it.agent }
                .mapValues { (_, rows) ->
                    rows.map { it.strategy }.toSet()
                }

        agents().forEach { row ->

            assertTrue(
                row.strategy in pools.getValue(row.agent),
                "${row.agent} played ${row.strategy}, " +
                    "which is not in its assigned pool"
            )
        }
    }

    @Test
    fun `strategy changes only after evaluation rounds`() {
        agents()
            .groupBy { it.agent }
            .forEach { (agent, rows) ->

                val ordered =
                    rows.sortedBy { it.round }

                ordered
                    .zipWithNext()
                    .forEach { (previous, current) ->

                        if (previous.strategy != current.strategy) {

                            assertEquals(
                                0,
                                previous.round % 3,
                                "$agent switched from " +
                                    "${previous.strategy} to ${current.strategy} " +
                                    "between rounds ${previous.round} and " +
                                    "${current.round}, but round ${previous.round} " +
                                    "was not an evaluation round"
                            )
                        }
                    }
            }
    }

    @Test
    fun `strategy evaluation counter increases every round`() {
        strategies()
            .groupBy {
                Pair(it.agent, it.strategy)
            }
            .forEach { (key, rows) ->

                val ordered =
                    rows.sortedBy { it.round }

                ordered.forEachIndexed { index, row ->

                    assertEquals(
                        index + 1,
                        row.evaluations,
                        "${key.first}/${key.second}: " +
                            "unexpected evaluation count in round ${row.round}"
                    )
                }
            }
    }

    @Test
    fun `no numeric result is NaN or infinite`() {
        rounds().forEach {
            assertTrue(it.totalBid.isFinite())
            assertTrue(it.averageBid.isFinite())
            assertTrue(it.groupRent.isFinite())
            assertTrue(it.rentPct.isFinite())
        }

        agents().forEach {
            assertTrue(it.bid.isFinite())
            assertTrue(it.market1.isFinite())
            assertTrue(it.market2.isFinite())
            assertTrue(it.payoff.isFinite())
        }

        strategies().forEach {
            assertTrue(it.candidateBid.isFinite())
            assertTrue(it.counterfactualPayoff.isFinite())
            assertTrue(it.sum.isFinite())
        }
    }

    @Test
    fun `agents exhibit more than one bid trajectory`() {
        val trajectories =
            agents()
                .groupBy { it.agent }
                .mapValues { (_, rows) ->
                    rows
                        .sortedBy { it.round }
                        .map { it.bid }
                }

        val uniqueTrajectories =
            trajectories.values.toSet()

        println(
            "Unique agent bid trajectories: " +
                "${uniqueTrajectories.size}/${trajectories.size}"
        )

        assertTrue(
            uniqueTrajectories.size > 1,
            "All agents followed exactly the same bid trajectory"
        )
    }
}