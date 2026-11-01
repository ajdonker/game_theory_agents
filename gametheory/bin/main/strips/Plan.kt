package strips

import it.unibo.tuprolog.core.Integer
import it.unibo.tuprolog.core.Struct
import it.unibo.tuprolog.core.Var
import it.unibo.tuprolog.core.parsing.TermParser
import it.unibo.tuprolog.solve.Solution
import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.Term

class plan : DefaultInternalAction() {

    companion object {

        private val solver by lazy {
            val engine = Main.createEngineWithTheory(World.load("Strips_Planner"))
            engine.assertA(Struct.of("max_depth", Integer.of(10)))
            engine
        }

        fun solveInterventionPlan(state: Iterable<String>): String? {
            val normalizedState = state.toMutableList()
            if (normalizedState.none { it.startsWith("mode_") }) {
                normalizedState.add("mode_none")
            }

            val stateList = normalizedState.joinToString(", ", prefix = "[", postfix = "]") { it }
            val queryString = "intervention_plan($stateList, Plan)."
            val query = TermParser.withOperators(solver.operators).parseStruct(queryString)
            val solution = solver.solve(query).firstOrNull() ?: return null

            if (solution !is Solution.Yes) {
                return null
            }

            val planVariable = query.args[1] as? Var ?: return null
            val planTerm = solution.substitution[planVariable] ?: return null
            val plan = planTerm.toString()
            if (plan == "[]") {
                return normalizedState.firstOrNull { it.startsWith("mode_") }
                    ?.removePrefix("mode_")
            }

            val action = plan
                .removePrefix("[")
                .removeSuffix("]")
                .split(",")
                .firstOrNull()
                ?.trim()
                ?: return null

            return when (action) {
                "enable_centralized" -> "centralized"
                "switch_decentralized_to_centralized",
                "switch_coalition_to_centralized" -> "centralized"
                "enable_coalitions" -> "coalition"
                "enable_decentralized" -> "decentralized"
                "switch_centralized_to_decentralized",
                "switch_coalition_to_decentralized",
                "disable_coalitions" -> "decentralized"
                "disable_centralized",
                "disable_decentralized",
                "disable_coalition_for_optimal_investment" -> "none"
                else -> action
            }
        }
    }

    override fun execute(
        ts: TransitionSystem,
        un: Unifier,
        args: Array<Term>
    ): Any {
        val bestStrategy = args[0].toString()
        val queryString = "central_plan($bestStrategy, Plan)."
        val query = TermParser.withOperators(solver.operators).parseStruct(queryString)
        val solution = solver.solve(query).firstOrNull()

        println("STRIPS QUERY: $queryString")
        println("STRIPS SOLUTION: $solution")

        val success = solution is Solution.Yes

        if (success) {
            ts.ag.logger.info("STRIPS accepted enforcement of $bestStrategy")
        } else {
            ts.ag.logger.warning("STRIPS could not find a plan for $bestStrategy")
        }

        return success
    }
}