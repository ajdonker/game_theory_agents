package gui

import com.google.gson.JsonObject
import com.google.gson.JsonParser

object SimulationEventParser {

    private const val PREFIX = "CPR_EVENT|"

    fun parse(line: String): SimulationEvent? {
        val index = line.indexOf(PREFIX)
        if (index < 0) return null

        return try {
            val json = JsonParser.parseString(
                line.substring(index + PREFIX.length).trim()
            ).asJsonObject

            decode(json)

        } catch (e: Exception) {
            System.err.println("Event parse error: ${e.message}")
            null
        }
    }

    private fun decode(json: JsonObject): SimulationEvent? {

        val round = json.get("round")?.asInt
            ?: return null

        return when (json.get("type")?.asString) {

            "round_finished" ->
                SimulationEvent.RoundFinished(
                    round = round,
                    totalInvestment = json.get("totalInvestment").asDouble,
                    rentPct = json.get("rentPct").asDouble,
                    distanceToOptimum = json.get("distanceToOptimum").asDouble
                )

            "agent_result" ->
                SimulationEvent.AgentResult(
                    round = round,
                    agent = json.get("agent").asString,
                    bid = json.get("bid").asDouble,
                    payoff = json.get("payoff").asDouble,
                    strategy = json.get("strategy").asString
                )

            "planner_decision" ->
                SimulationEvent.PlannerDecision(
                    round = round,
                    symbolicState = json.getAsJsonArray("symbolicState")
                        .map { it.asString },
                    plan = json.getAsJsonArray("plan")
                        .map { it.asString },
                    selectedMode = json.get("selectedMode").asString
                )


            "intervention_decision" ->
                SimulationEvent.InterventionDecision(
                    round = round,
                    currentMode = json.get("currentMode").asString,
                    proposedMode = json.get("proposedMode").asString,
                    selectedMode = json.get("selectedMode").asString,
                    modeAge = json.get("modeAge").asInt,
                    optimalCount = json.get("optimalCount").asInt
                )

            "intervention_applied" ->
                SimulationEvent.InterventionApplied(
                    round = round,
                    mode = json.get("mode").asString,
                    success = json.get("success").asBoolean
                )

            "coalition_changed" ->
                SimulationEvent.CoalitionChanged(
                    round = round,
                    coalitionId = json.get("coalitionId").asString,
                    members = json.getAsJsonArray("members")
                        .map { it.asString },
                    change = json.get("change").asString
                )

            "planner_failed" ->
                SimulationEvent.PlannerFailed(
                    round = round,
                    reason = json.get("reason").asString
                )

            "simulation_finished" ->
                SimulationEvent.SimulationFinished(
                    round = round
                )

            else -> null
        }
    }
}
