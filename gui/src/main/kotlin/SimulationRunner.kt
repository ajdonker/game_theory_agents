interface SimulationRunner {
    fun start(config: ExperimentConfig)
    fun stop()
    fun isRunning(): Boolean
}