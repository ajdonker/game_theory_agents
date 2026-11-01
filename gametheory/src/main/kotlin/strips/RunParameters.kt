package strips

data class RunParameters(
    val runId: Int?,
    val seed: Long?,
    val rounds: Int?
) {
    companion object {
        fun fromJvm(): RunParameters {
            return RunParameters(
                runId = System.getProperty("cpr.runId")?.toInt(),
                seed = System.getProperty("cpr.seed")?.toLong(),
                rounds = System.getProperty("cpr.rounds")?.toInt()
            )
        }
    }
}