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

        val groupTotal = number(0)
        val optimalGroupInvestment = number(1)
        val bids = (2..9).map(::number)
        val currentMode = when (args[10].toString()) {
            "no_intervention", "none" -> "mode_none"
            "centralized" -> "mode_centralized"
            "decentralized" -> "mode_decentralized"
            "coalition" -> "mode_coalition"
            else -> {
                ts.ag.logger.warning("Unknown current intervention: ${args[10]}")
                return false
            }
        }

        val relativeErr = when {
            optimalGroupInvestment == 0.0 -> when {
                groupTotal == 0.0 -> 0.0
                groupTotal > 0.0 -> Double.POSITIVE_INFINITY
                else -> Double.NEGATIVE_INFINITY
            }
            else -> (groupTotal - optimalGroupInvestment) / optimalGroupInvestment
        }

        val investment = when {
            relativeErr < -0.10 -> "investment_low"
            relativeErr > 0.10 -> "investment_high"
            else -> "investment_optimal"
        }

        val avg = bids.average()
        val variance = bids.map { (it - avg) * (it - avg) }.average()
        val dispersion = if (sqrt(variance) > 2.0) "dispersion_high" else "dispersion_low"

        val intervention = plan.solveInterventionPlan(listOf(investment, dispersion, currentMode))
        if (intervention == null) {
            ts.ag.logger.warning("STRIPS could not find an intervention for $investment, $dispersion, $currentMode")
            return false
        }

        return un.unifies(args[11], Atom(intervention))
    }
}