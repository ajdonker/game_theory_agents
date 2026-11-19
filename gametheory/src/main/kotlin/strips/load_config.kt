package strips

import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.NumberTermImpl
import jason.asSyntax.Term

/** Jason internal action that loads run ID, seed, and round parameters from JVM properties. */
class load_config: DefaultInternalAction() {
    override fun execute(ts: TransitionSystem, un: Unifier, args: Array<Term>): Any {
        if (args.size != 3) {
            return false
        }
        val config = RunParameters.fromJvm()

        val runId = config.runId ?: return false
        val seed = config.seed ?: return false
        val rounds = config.rounds ?: return false

        if(runId < 1 || rounds < 1) return false

        println(
            "GUI CONFIG: run=$runId, seed=$seed, " +
                    "rounds=$rounds"
        )
        return un.unifies(args[0], NumberTermImpl(runId.toDouble())) &&
                un.unifies(args[1], NumberTermImpl(seed.toDouble())) &&
                un.unifies(args[2], NumberTermImpl(rounds.toDouble()))
    }
}