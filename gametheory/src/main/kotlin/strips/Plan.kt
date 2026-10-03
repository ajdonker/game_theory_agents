package strips

import it.unibo.tuprolog.core.Integer
import it.unibo.tuprolog.core.Struct
import it.unibo.tuprolog.core.parsing.TermParser
import it.unibo.tuprolog.solve.Solution
import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.Term

class plan : DefaultInternalAction() {

    companion object {

        // Created only once, rather than once per round
        private val solver by lazy {

            val engine =
                Main.createEngineWithTheory(
                    World.load("Strips_Planner")
                )

            engine.assertA(
                Struct.of(
                    "max_depth",
                    Integer.of(10)
                )
            )

            engine
        }
    }

    override fun execute(
        ts: TransitionSystem,
        un: Unifier,
        args: Array<Term>
    ): Any {

        val bestStrategy =
            args[0].toString()

        val queryString =
            "central_plan($bestStrategy, Plan)."

        val query =
            TermParser
                .withOperators(solver.operators)
                .parseStruct(queryString)

        val solution =
            solver.solve(query).first()

        println("STRIPS QUERY: $queryString")
        println("STRIPS SOLUTION: $solution")
        
        val success =
            solution is Solution.Yes

        if (success) {
            ts.ag.logger.info(
                "STRIPS accepted enforcement of $bestStrategy"
            )
        } else {
            ts.ag.logger.warning(
                "STRIPS could not find a plan for $bestStrategy"
            )
        }

        return success
    }
}