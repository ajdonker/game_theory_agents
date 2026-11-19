
package strips

import com.google.gson.*
import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.*

/** Jason internal action that validates and emits simulation events as JSON-prefixed console output. */
class emit_event : DefaultInternalAction() {

    private val schemas = mapOf(
        "round_finished" to listOf(
            "round", "totalInvestment",
            "rentPct", "distanceToOptimum"
        ),

        "agent_result" to listOf(
                "round", "agent", "bid",
                "payoff", "strategy"
        ),
        "planner_decision" to listOf(
            "round", "symbolicState",
            "plan", "selectedMode"
        ),
        "intervention_applied" to listOf(
            "round", "mode", "success"
        ),
        "coalition_changed" to listOf(
            "round", "coalitionId",
            "members", "change"
        ),
        "planner_failed" to listOf(
            "round", "reason"
        ),
        "simulation_finished" to listOf(
            "round"
        ),
        "intervention_decision" to listOf(
            "round",
            "currentMode",
            "proposedMode",
            "selectedMode",
            "modeAge",
            "optimalCount"
        ),
        "mode_active" to listOf("round", "mode")
    )

    override fun execute(
        ts: TransitionSystem,
        un: Unifier,
        args: Array<Term>
    ): Any {

        if (args.size != 1) return false

        val event = args[0] as? Structure
            ?: return false

        val fields = schemas[event.functor]
            ?: return false

        if (event.arity != fields.size) return false

        val json = encode(event)
            ?: return false

        println(json)
        return true 
    }


    internal fun encode(event: Structure): String? {

        val fields = schemas[event.functor]
            ?: return null

        if (event.arity != fields.size) return null

        val json = JsonObject()
        json.addProperty("type", event.functor)

        fields.forEachIndexed { index, field ->
            json.add(
                field,
                toJson(event.getTerm(index))
            )
        }

        return "CPR_EVENT|$json"
    }
    private fun toJson(term: Term): JsonElement =
        when (term) {

            is NumberTerm ->
                JsonPrimitive(term.solve())

            is StringTerm ->
                JsonPrimitive(term.string)

            is ListTerm -> {
                val array = JsonArray()
                term.forEach {
                    array.add(toJson(it))
                }
                array
            }

            else -> when (term.toString()) {
                "true" -> JsonPrimitive(true)
                "false" -> JsonPrimitive(false)
                else -> JsonPrimitive(term.toString())
            }
        }
}
