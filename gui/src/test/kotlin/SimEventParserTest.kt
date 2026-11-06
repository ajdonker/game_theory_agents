
package gui

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class SimulationEventParserTest {

    @Test
    fun `round event parses correctly`() {
        val line = """
            CPR_EVENT|{
                "type":"round_finished",
                "round":5,
                "totalInvestment":72.0,
                "rentPct":0.0,
                "distanceToOptimum":36.0
            }
        """.trimIndent().replace("\n", "")

        val event = assertInstanceOf(
            SimulationEvent.RoundFinished::class.java,
            SimulationEventParser.parse(line)
        )

        assertEquals(5, event.round)
        assertEquals(72.0, event.totalInvestment)
        assertEquals(0.0, event.rentPct)
        assertEquals(36.0, event.distanceToOptimum)
    }

    @Test
    fun `agent result parses correctly`() {
        val line = """
            CPR_EVENT|{
                "type":"agent_result",
                "round":10,
                "agent":"agent1",
                "bid":5.0,
                "payoff":20.0,
                "strategy":"cooperate"
            }
        """.trimIndent().replace("\n", "")

        val event = assertInstanceOf(
            SimulationEvent.AgentResult::class.java,
            SimulationEventParser.parse(line)
        )

        assertEquals(10, event.round)
        assertEquals("agent1", event.agent)
        assertEquals(5.0, event.bid)
        assertEquals(20.0, event.payoff)
        assertEquals("cooperate", event.strategy)
        assertNull(event.coalitionId)
    }

    @Test
    fun `planner decision parses correctly`() {
        val line = """
            CPR_EVENT|{
                "type":"planner_decision",
                "round":10,
                "symbolicState":["investment_high","mode_none"],
                "plan":["enable_communication","activate_centralized"],
                "selectedMode":"centralized"
            }
        """.trimIndent().replace("\n", "")

        val event = assertInstanceOf(
            SimulationEvent.PlannerDecision::class.java,
            SimulationEventParser.parse(line)
        )

        assertEquals(10, event.round)

        assertEquals(
            listOf("investment_high", "mode_none"),
            event.symbolicState
        )

        assertEquals(
            listOf("enable_communication", "activate_centralized"),
            event.plan
        )

        assertEquals("centralized", event.selectedMode)
    }

    @Test
    fun `intervention decision parses correctly`() {
        val line = """
            CPR_EVENT|{
                "type":"intervention_decision",
                "round":10,
                "currentMode":"none",
                "proposedMode":"centralized",
                "selectedMode":"decentralized",
                "modeAge":3,
                "optimalCount":0
            }
        """.trimIndent().replace("\n", "")

        val event = assertInstanceOf(
            SimulationEvent.InterventionDecision::class.java,
            SimulationEventParser.parse(line)
        )

        assertEquals(10, event.round)
        assertEquals("none", event.currentMode)
        assertEquals("centralized", event.proposedMode)
        assertEquals("decentralized", event.selectedMode)
        assertEquals(3, event.modeAge)
        assertEquals(0, event.optimalCount)
    }

    @Test
    fun `intervention applied parses correctly`() {
        val line = """
            CPR_EVENT|{
                "type":"intervention_applied",
                "round":10,
                "mode":"centralized",
                "success":true
            }
        """.trimIndent().replace("\n", "")

        val event = assertInstanceOf(
            SimulationEvent.InterventionApplied::class.java,
            SimulationEventParser.parse(line)
        )

        assertEquals(10, event.round)
        assertEquals("centralized", event.mode)
        assertTrue(event.success)
    }

    @Test
    fun `failed intervention is parsed correctly`() {
        val line = """
            CPR_EVENT|{
                "type":"intervention_applied",
                "round":11,
                "mode":"decentralized",
                "success":false
            }
        """.trimIndent().replace("\n", "")

        val event = assertInstanceOf(
            SimulationEvent.InterventionApplied::class.java,
            SimulationEventParser.parse(line)
        )

        assertEquals(11, event.round)
        assertEquals("decentralized", event.mode)
        assertFalse(event.success)
    }

    @Test
    fun `coalition change parses correctly`() {
        val line = """
            CPR_EVENT|{
                "type":"coalition_changed",
                "round":15,
                "coalitionId":"coalition1",
                "members":["agent1","agent3","agent5"],
                "change":"formed"
            }
        """.trimIndent().replace("\n", "")

        val event = assertInstanceOf(
            SimulationEvent.CoalitionChanged::class.java,
            SimulationEventParser.parse(line)
        )

        assertEquals(15, event.round)
        assertEquals("coalition1", event.coalitionId)

        assertEquals(
            listOf("agent1", "agent3", "agent5"),
            event.members
        )

        assertEquals("formed", event.change)
    }

    @Test
    fun `planner failure parses correctly`() {
        val line = """
            CPR_EVENT|{
                "type":"planner_failed",
                "round":20,
                "reason":"no applicable plan"
            }
        """.trimIndent().replace("\n", "")

        val event = assertInstanceOf(
            SimulationEvent.PlannerFailed::class.java,
            SimulationEventParser.parse(line)
        )

        assertEquals(20, event.round)
        assertEquals("no applicable plan", event.reason)
    }

    @Test
    fun `simulation finished parses correctly`() {
        val line = """
            CPR_EVENT|{
                "type":"simulation_finished",
                "round":300
            }
        """.trimIndent().replace("\n", "")

        val event = assertInstanceOf(
            SimulationEvent.SimulationFinished::class.java,
            SimulationEventParser.parse(line)
        )

        assertEquals(300, event.round)
        assertNull(event.meanRentPct)
        assertNull(event.meanDistance)
    }

    @Test
    fun `ordinary logs are ignored`() {
        val line = "STARTING ROUND 10"

        assertNull(SimulationEventParser.parse(line))
    }

    @Test
    fun `malformed JSON is rejected`() {
        val line = "CPR_EVENT|{invalid}"

        assertNull(SimulationEventParser.parse(line))
    }

    @Test
    fun `unknown event type is ignored`() {
        val line = """
            CPR_EVENT|{
                "type":"unknown_event",
                "round":10
            }
        """.trimIndent().replace("\n", "")

        assertNull(SimulationEventParser.parse(line))
    }

    @Test
    fun `missing required fields are rejected`() {
        val line = """
            CPR_EVENT|{
                "type":"agent_result",
                "round":10,
                "agent":"agent1"
            }
        """.trimIndent().replace("\n", "")

        assertNull(SimulationEventParser.parse(line))
    }

    @Test
    fun `Jason logging prefix is handled`() {
        val line = """
            [planner] CPR_EVENT|{"type":"simulation_finished","round":5}
        """.trimIndent()

        val event = assertInstanceOf(
            SimulationEvent.SimulationFinished::class.java,
            SimulationEventParser.parse(line)
        )

        assertEquals(5, event.round)
    }
}
