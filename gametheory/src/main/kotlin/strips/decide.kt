package strips

import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.Atom
import jason.asSyntax.NumberTerm
import jason.asSyntax.Term
import kotlin.math.sqrt

class decide : DefaultInternalAction() {
    override fun getMinArgs() = 13
    override fun getMaxArgs() = 13

    override fun execute(
        ts: TransitionSystem,
        un: Unifier,
        args: Array<Term>
    ): Any? {
        fun number(i: Int): Double = (args[i] as NumberTerm).solve()

        val groupTotal = number(0)
        val optimalGroupInvestment = number(1)
        val rentPct = number(2)
        val bids = (3..10).map(::number)
        val currentMode = when (args[11].toString()) {
            "no_intervention", "none" -> "mode_none"
            "centralized" -> "mode_centralized"
            "decentralized" -> "mode_decentralized"
            "coalition" -> "mode_coalition"
            else -> {
                ts.ag.logger.warning("Unknown current intervention: ${args[11]}")
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
            relativeErr < -0.15 -> "investment_low"
            relativeErr > 0.15 -> "investment_high"
            else -> "investment_optimal"
        }

        val avg = bids.average()
        val variance = bids.map { (it - avg) * (it - avg) }.average()
        val dispersion = if (sqrt(variance) > 2.0) "dispersion_high" else "dispersion_low"

        val state = listOf(investment, dispersion, currentMode)

//        println("========== STRIPS DEBUG ==========")
//        println("Group total: $groupTotal")
//        println("Optimal investment: $optimalGroupInvestment")
//        println("Rent percentage: $rentPct")
//        println("Relative error: $relativeErr")
//        println("State: $state")

        val action = try {
            plan.solveInterventionPlan(state)
        } catch (e: Exception) {
            println("STRIPS EXCEPTION:")
            e.printStackTrace()
            return false
        }

//        println("STRIPS RETURNED ACTION: $action")
//        println("==================================")
        if (investment == "investment_optimal" && currentMode == "mode_none") {
            println("STRIPS: Already optimal, no intervention needed")
            return un.unifies(args[12], Atom("keep"))
        }
        //val action = plan.solveInterventionPlan(listOf(investment, dispersion, currentMode))
        if (action == null) {
            ts.ag.logger.warning("STRIPS could not find an applicable action for $investment, $dispersion, $currentMode")
            return false
        }
        val intervention = when (action) {

            "none",
            "centralized",
            "decentralized",
            "coalition",
            "keep" -> action

            "maintain_centralized",
            "maintain_decentralized",
            "maintain_coalitions" -> "keep"

            "disable_coalitions",
            "disable_centralized",
            "disable_coalition_for_optimal_investment",
            "disable_decentralized" -> "none"

            "enable_centralized",
            "switch_decentralized_to_centralized",
            "switch_coalition_to_centralized" -> "centralized"

            "enable_decentralized",
            "switch_centralized_to_decentralized",
            "switch_coalition_to_decentralized",
            "prepare_coalitions_from_none",
            "prepare_coalitions_from_centralized" -> "decentralized"

            "enable_coalitions" -> "coalition"

            else -> {
                ts.ag.logger.warning("no applicable action: $action")
                return false
            }
        }
        println("STRIPS STATE: $investment, $dispersion, $currentMode")
        println("STRIPS ACTION: $action")
        println("NEXT INTERVENTION: $intervention")

        return un.unifies(args[12], Atom(intervention))
    }
}