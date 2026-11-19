package gui

/** Represents typed events emitted by a simulation and consumed by the GUI. */
sealed interface SimulationEvent {
    val round: Int

    /** Reports aggregate investment and performance metrics for a completed round. */
    data class RoundFinished(
        override val round: Int,
        val totalInvestment: Double? = null,
        val rentPct: Double? = null,
        val distanceToOptimum: Double? = null
    ) : SimulationEvent

    /** Reports one agent's bid, payoff, strategy, and optional coalition membership. */
    data class AgentResult(
        override val round: Int,
        val agent: String,
        val bid: Double,
        val payoff: Double,
        val strategy: String,
        val coalitionId: String? = null
    ) : SimulationEvent

    /** Reports the symbolic state and plan produced by the STRIPS planner. */
    data class PlannerDecision(
        override val round: Int,
        val symbolicState: List<String>,
        val plan: List<String>,
        val selectedMode: String
    ) : SimulationEvent

    /** Reports a proposed intervention and the stability-gated mode selected for it. */
    data class InterventionDecision(
        override val round: Int,
        val currentMode: String,
        val proposedMode: String,
        val selectedMode: String,
        val modeAge: Int,
        val optimalCount: Int
    ) : SimulationEvent

    /** Reports whether an intervention mode was successfully applied. */
    data class InterventionApplied(
        override val round: Int,
        val mode: String,
        val success: Boolean
    ) : SimulationEvent

    /** Reports a coalition membership change during a round. */
    data class CoalitionChanged(
        override val round: Int,
        val coalitionId: String,
        val members: List<String>,
        val change: String
    ) : SimulationEvent

    /** Reports a round in which the STRIPS planner could not produce a plan. */
    data class PlannerFailed(
        override val round: Int,
        val reason: String
    ) : SimulationEvent

    /** Reports completion of a simulation and optional aggregate summary metrics. */
    data class SimulationFinished(
        override val round: Int,
        val meanRentPct: Double? = null,
        val meanDistance: Double? = null
    ) : SimulationEvent

    /** Reports the intervention mode active at a particular round. */
    data class ModeActive(
        override val round: Int,
        val mode: String
    ) : SimulationEvent
}