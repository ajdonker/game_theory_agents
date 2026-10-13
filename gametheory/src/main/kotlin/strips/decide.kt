package strips

import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.Atom
import jason.asSyntax.NumberTerm
import jason.asSyntax.Term
import kotlin.math.sqrt

class decide : DefaultInternalAction() {
    override fun getMinArgs() = 12
    override fun getMaxArgs() = 12

    override fun execute(
        ts: TransitionSystem,
        un: Unifier,
        args: Array<Term>
    ): Any {
        fun number(i: Int): Double = (args[i] as NumberTerm).solve()

        val total = number(0)
        val optimal = number(1)
        val rentPct = number(2)
        val bids = (3..10).map(::number)

        val relativeErr = when {
            optimal == 0.0 -> when {
                total == 0.0 -> 0.0
                total > 0.0 -> Double.POSITIVE_INFINITY
                else -> Double.NEGATIVE_INFINITY
            }
            else -> (total - optimal) / optimal
        }

        val investment = when {
            relativeErr < -0.10 -> "investment_low"
            relativeErr > 0.10 -> "investment_high"
            else -> "investment_optimal"
        }

        val performance = when {
            rentPct >= 90.0 -> "performance_high"
            rentPct >= 60.0 -> "performance_medium"
            else -> "performance_low"
        }

        val avg = bids.average()
        val variance = bids.map { (it - avg) * (it - avg) }.average()
        val dispersion = if (sqrt(variance) > 2.0) "dispersion_high" else "dispersion_low"

        val intervention = plan.solveInterventionPlan(listOf(investment, performance, dispersion))
            ?: when {
                investment == "investment_optimal" -> "none"
                investment == "investment_high" && performance == "performance_low" -> "centralized"
                investment == "investment_high" && dispersion == "dispersion_high" -> "coalition"
                investment == "investment_high" -> "centralized"
                investment == "investment_low" -> "coalition"
                else -> "none"
            }

        return un.unifies(args[11], Atom(intervention))
    }
}