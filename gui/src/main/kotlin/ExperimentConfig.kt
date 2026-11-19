package gui
/** Available communication and intervention modes for an experiment. */
enum class Scenario {
    NO_COMM,
    DECENTRALIZED,
    CENTRALIZED,
    COALITION,
    ADAPTIVE
}
/** Configuration for one simulation run, including its scenario, seed, and round count. */
data class ExperimentConfig (
    val runId: Int = 3,
    val seed: Long = 42L,
    val rounds: Int= 300,
    val scenario: Scenario = Scenario.NO_COMM
)
/** Configuration for generating a sequence of parameterized experiment runs. */
data class BatchConfig(
    val count: Int = 30,
    val firstRunId: Int = 1,
    val firstSeed: Long = 42L,
) {
    fun generate(base: ExperimentConfig): List<ExperimentConfig> {
        require(count in 1..1000) {
            "Number of runs must be between 1 and 1000"
        }

        return List(count) { i ->
            val id = Math.addExact(firstRunId, i)
            val seed = Math.addExact(firstSeed, i.toLong())

            require(id in 1..1_000_000) {
                "Run ID out of range: $id"
            }
            require(seed >= 0) {
                "Seed must be nonnegative"
            }

            base.copy(
                runId = id,
                seed = seed
            )
        }
    }
}