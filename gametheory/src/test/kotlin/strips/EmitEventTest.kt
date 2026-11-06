
package strips

import com.google.gson.JsonParser
import jason.asSyntax.ASSyntax
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class EmitEventTest {
    /*test validity of event emission from Jason to JSON, with testable guarantees on every type that can be serialized.*/
    private val emitter = emit_event()

    private fun encoded(source: String) =
        JsonParser.parseString(
            requireNotNull(emitter.encode(ASSyntax.parseStructure(source)))
                .removePrefix("CPR_EVENT|")
        ).asJsonObject

    @Test
    fun `round numeric fields are serialized`() {
        val json = encoded("round_finished(5,72,0,36)")
        assertEquals("round_finished", json.get("type").asString)
        assertEquals(5, json.get("round").asInt)
        assertEquals(72.0, json.get("totalInvestment").asDouble)
        assertEquals(0.0, json.get("rentPct").asDouble)
        assertEquals(36.0, json.get("distanceToOptimum").asDouble)
    }

    @Test
    fun `Jason lists become JSON arrays and preserve order`() {
        val json = encoded(
            "planner_decision(7,[investment_high,mode_none],[enable_communication,enforce_bid(4)],centralized)"
        )
        assertEquals(
            listOf("investment_high", "mode_none"),
            json.getAsJsonArray("symbolicState").map { it.asString }
        )
        assertEquals(
            listOf("enable_communication", "enforce_bid(4)"),
            json.getAsJsonArray("plan").map { it.asString }
        )
        assertEquals("centralized", json.get("selectedMode").asString)
    }

    @Test
    fun `boolean atoms are serialized as booleans`() {
        val json = encoded("intervention_applied(7,centralized,true)")
        assertTrue(json.get("success").asBoolean)
        assertEquals("centralized", json.get("mode").asString)
    }

    @Test
    fun `bad functor or arity are rejected`() {
        assertNull(emitter.encode(ASSyntax.parseStructure("unknown_event(1)")))
        assertNull(emitter.encode(ASSyntax.parseStructure("round_finished(1,2)")))
    }
}
