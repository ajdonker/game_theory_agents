
package strips

import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.ListTerm
import jason.asSyntax.ListTermImpl
import jason.asSyntax.NumberTerm
import jason.asSyntax.Term
import java.util.Random

/** Jason internal action that deterministically shuffles a Jason list using a supplied seed. */
class seeded_shuffle : DefaultInternalAction() {

    override fun execute(
        ts: TransitionSystem,
        un: Unifier,
        args: Array<Term>
    ): Any {
        val strategies = (args[0] as ListTerm)
            .getAsList()
            .toMutableList()

        val seed = (args[1] as NumberTerm)
            .solve()
            .toLong()

        strategies.shuffle(Random(seed))

        val result = ListTermImpl()
        result.addAll(strategies)

        return un.unifies(args[2], result)
    }
}
