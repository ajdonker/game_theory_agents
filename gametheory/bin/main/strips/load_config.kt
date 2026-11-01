package strips

import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.NumberTermImpl
import jason.asSyntax.Term

class load_config: DefaultInternalAction() {
    override fun execute(ts: TransitionSystem, un: Unifier, args: Array<Term>): Any {
        if (args.size != 3) {
            return false
        }
        val config = RunParameters.fromJvm()

        val runId = config.runId ?: 1
        val seed = config.seed ?: 42L
        val rounds = config.rounds ?: 100

        println(
            "GUI CONFIG: run=$runId, seed=$seed, " +
                    "rounds=$rounds"
        )
        return un.unifies(args[0], NumberTermImpl(runId.toDouble())) &&
                un.unifies(args[1], NumberTermImpl(seed.toDouble())) &&
                un.unifies(args[2], NumberTermImpl(rounds.toDouble()))
    }
}