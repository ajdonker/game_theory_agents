package gui

sealed interface SimulationEvent {
    val round: Int

    data class RoundFinished(
        override val round: Int,
        val totalInvestment: Double? = null,
        val rentPct: Double? = null,
        val distanceToOptimum: Double? = null
    ) : SimulationEvent

    data class AgentResult(
        override val round: Int,
        val agent: String,
        val bid: Double,
        val payoff: Double,
        val strategy: String,
        val coalitionId: String? = null
    ) : SimulationEvent

    data class PlannerDecision(
        override val round: Int,
        val symbolicState: List<String>,
        val plan: List<String>,
        val selectedMode: String
    ) : SimulationEvent

    data class InterventionDecision(
        override val round: Int,
        val currentMode: String,
        val proposedMode: String,
        val selectedMode: String,
        val modeAge: Int,
        val optimalCount: Int
    ) : SimulationEvent

    data class InterventionApplied(
        override val round: Int,
        val mode: String,
        val success: Boolean
    ) : SimulationEvent

    data class CoalitionChanged(
        override val round: Int,
        val coalitionId: String,
        val members: List<String>,
        val change: String
    ) : SimulationEvent

    data class PlannerFailed(
        override val round: Int,
        val reason: String
    ) : SimulationEvent

    data class SimulationFinished(
        override val round: Int,
        val meanRentPct: Double? = null,
        val meanDistance: Double? = null
    ) : SimulationEvent
}