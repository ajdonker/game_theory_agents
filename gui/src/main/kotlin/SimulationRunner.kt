package gui

/** Common lifecycle contract for starting and stopping a simulation process. */
interface SimulationRunner {
    fun start(config: ExperimentConfig)
    fun stop()
    fun isRunning(): Boolean
}