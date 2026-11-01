package strips

data class RunParameters(
    val runId: Int?,
    val seed: Long?,
    val rounds: Int?,
    val scenario: String?
) {
    companion object {
        fun fromJvm(): RunParameters {
            return RunParameters(
                runId = System.getProperty("cprRunId")?.toInt(),
                seed = System.getProperty("cprSeed")?.toLong(),
                rounds = System.getProperty("cprRounds")?.toInt(),
                scenario = System.getProperty("cprScenario")
            )
        }
    }
}