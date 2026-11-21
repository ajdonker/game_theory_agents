
package strips

import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.NumberTermImpl
import jason.asSyntax.Term

import java.nio.file.Files
import java.nio.file.Path
import java.util.Properties

/**
 * Reads simulation parameters from a shared properties file.
 *
 * Usage in Jason:
 *     strips.param(endowment, E).
 *     strips.param(trust_threshold, T).
 *
 * JVM properties override values from the configuration file.
 */
class param : DefaultInternalAction() {

    companion object {
        private val keys = mapOf(
            // Economic environment
            "endowment" to "game.endowment",
            "market1_return" to "game.market1Return",
            "cpr_a" to "game.cprA",
            "cpr_b" to "game.cprB",

            // Agent behaviour
            "comm_interval" to "agent.communicationInterval",
            "strat_reeval_interval" to "agent.strategyReevaluationInterval",

            // Adaptive planner
            "exploration_rounds" to "planner.explorationRounds",
            "intervention_min_duration" to "planner.minDuration",
            "min_rounds_optimal" to "planner.minOptimalRounds",
            "optimality_window" to "planner.optimalityWindow",
            "optimal_tolerance" to "planner.optimalTolerance",

            "centralized_window" to "planner.centralizedWindow",
            "decentralized_window" to "planner.decentralizedWindow",

            "stab_round_threshold_centralized" to
                    "planner.centralizedStableCount",

            "ineffective_round_threshold_centralized" to
                    "planner.centralizedIneffectiveCount",

            "ineffective_round_threshold_decentralized" to
                    "planner.decentralizedIneffectiveCount",

            "good_perf_lim_centralized" to
                    "planner.centralizedGoodRent",

            "bad_perf_lim_centralized" to
                    "planner.centralizedBadRent",

            "good_perf_lim_decentralized" to
                    "planner.decentralizedGoodRent",

            // Coalition
            "trust_threshold" to "coalition.trustThreshold",
            "trust_learning_rate" to "coalition.trustLearningRate",
            "trust_max_step" to "coalition.trustMaxStep",
            "default_trust" to "coalition.defaultTrust",
            "max_coalition_peers" to "coalition.maxPeers",
            "coalition_bid_threshold" to "coalition.bidThreshold",
            "coalitioning_rate" to "coalition.coalitioningRate",

            // parameters for decide.kt
            "dispersion_threshold" to "planner.dispersionThreshold"
        )

        private fun configPath(): Path {
            val explicit = System.getProperty("ise.config")

            if (!explicit.isNullOrBlank()) {
                return Path.of(explicit)
            }

            // Support launching from repository or module root.
            val candidates = listOf(
                Path.of("gametheory/config/default.properties"),
                Path.of("config/default.properties")
            )

            return candidates.firstOrNull { Files.isRegularFile(it) }
                ?: error("Cannot find config/default.properties")
        }

        private fun loadProperties(): Properties {
            val path = configPath()
            require(Files.isRegularFile(path)) {
                "Configuration file does not exist: $path"
            }

            return Properties().apply {
                Files.newInputStream(path).use { load(it) }
            }
        }
    }

    override fun execute(
        ts: TransitionSystem,
        un: Unifier,
        args: Array<Term>
    ): Any {

        if (args.size != 2) return false

        val key = args[0].toString()

        val propertyName = keys[key]
            ?: error("Unknown simulation parameter: $key")

        val properties = loadProperties()

        // Explicit JVM properties take precedence.
        val rawValue =
            System.getProperty(propertyName)
                ?: properties.getProperty(propertyName)
                ?: error("Missing configuration parameter: $propertyName")

        val value = rawValue.trim().toDoubleOrNull()
            ?: error("Invalid numeric value for $propertyName: $rawValue")

        require(value.isFinite()) {
            "Non-finite parameter: $propertyName"
        }

        return un.unifies(
            args[1],
            NumberTermImpl(value)
        )
    }
}
