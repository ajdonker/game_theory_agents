
package strips

import java.nio.file.Files
import java.nio.file.Path
import java.util.Properties

object SimulationConfig {

    private val properties: Properties by lazy {
        val explicit = System.getProperty("ise.config")

        val path = if (!explicit.isNullOrBlank()) {
            Path.of(explicit)
        } else {
            listOf(
                Path.of("config/default.properties"),
                Path.of("gametheory/config/default.properties")
            ).firstOrNull { Files.isRegularFile(it) }
                ?: error("Configuration file not found")
        }

        Properties().apply {
            Files.newInputStream(path).use { load(it) }
        }
    }

    fun double(key: String): Double =
        (System.getProperty(key)
            ?: properties.getProperty(key)
            ?: error("Missing parameter: $key")).toDouble()

    fun int(key: String): Int =
        (System.getProperty(key)
            ?: properties.getProperty(key)
            ?: error("Missing parameter: $key")).toInt()

    val agentCount = 8
    val endowment get() = double("game.endowment")
    val market1Return get() = double("game.market1Return")
    val cprA get() = double("game.cprA")
    val cprB get() = double("game.cprB")
    val communicationInterval get() = int("agent.communicationInterval")
    val explorationRounds get() = int("planner.explorationRounds")
    val minDuration get() = int("planner.minDuration")
    val minOptimalRounds get() = int("planner.minOptimalRounds")
    val optimalityWindow get() = int("planner.optimalityWindow")
    val centralizedWindow get() = int("planner.centralizedWindow")
    val centralizedStableCount get() = int("planner.centralizedStableCount")
    val centralizedIneffectiveCount get() = int("planner.centralizedIneffectiveCount")
    val centralizedGoodRent get() = double("planner.centralizedGoodRent")
    val centralizedBadRent get() = double("planner.centralizedBadRent")
    val decentralizedWindow get() = int("planner.decentralizedWindow")
    val decentralizedIneffectiveCount get() = int("planner.decentralizedIneffectiveCount")
    val decentralizedGoodRent get() = double("planner.decentralizedGoodRent")
    val trustThreshold get() = double("coalition.trustThreshold")
    val bidThreshold get() = double("coalition.bidThreshold")
    val maxPeers get() = int("coalition.maxPeers")

    val optimum get() =
        (cprA - market1Return) / (2.0 * cprB)

    val optimalRent get() =
        optimum * (cprA - market1Return - cprB * optimum)

    val optimalTolerance get() =
        double("planner.optimalTolerance")

    val dispersionThreshold get() =
        double("planner.dispersionThreshold")
}
