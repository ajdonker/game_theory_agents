enum class Scenario {
    NO_COMM,
    DECENTRALIZED,
    CENTRALIZED,
    COALITION,
    ADAPTIVE
}
data class ExperimentConfig (
    val runId: Int = 3,
    val seed: Long = 42L,
    val rounds: Int= 300,
    val scenario: Scenario = Scenario.NO_COMM
)