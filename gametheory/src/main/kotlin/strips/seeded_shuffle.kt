
package strips

import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.ListTerm
import jason.asSyntax.ListTermImpl
import jason.asSyntax.NumberTerm
import jason.asSyntax.Term
import java.util.Collections
import java.util.Random

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

        Collections.shuffle(strategies, Random(seed))

        val result = ListTermImpl()
        result.addAll(strategies)

        return un.unifies(args[2], result)
    }
}
