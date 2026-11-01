package gui

object SimulationEventParser {
    private const val PREFIX = "CPR_EVENT|"

    fun parse(line: String): SimulationEvent? {
        val index = line.indexOf(PREFIX)
        if (index == -1) return null

        val data = line.substring(index + PREFIX.length).trim().split("|")

        return when (data.firstOrNull()) {
            "ROUND" -> {
                val round = data.getOrNull(1)?.toIntOrNull() ?: return null
                SimulationEvent.RoundFinished(round)
            }
            "INTERVENTION_APPLIED" -> {
                val round = data.getOrNull(1)?.toIntOrNull() ?: return null
                val mode = data.getOrNull(2) ?: return null
                val success = data.getOrNull(3)?.toBooleanStrictOrNull() ?: return null
                SimulationEvent.InterventionApplied(round, mode, success)
            }
            else -> null
        }
    }
}