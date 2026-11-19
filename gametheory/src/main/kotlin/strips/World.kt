package strips

import it.unibo.tuprolog.theory.Theory
import it.unibo.tuprolog.theory.parsing.ClausesReader
import java.net.URL

/** Provides STRIPS theory loading and composition for the selected simulation world. */
object World {
    private fun parseFileAsTheory(file: URL?): Theory {
        file!!.openStream().use { return ClausesReader.withDefaultOperators().readTheory(it) }
    }

    fun load(name: String): Theory {
        var theory = parseFileAsTheory(Main::class.java.getResource("/$name.pl"))
        theory += parseFileAsTheory(Main::class.java.getResource("/Strips.pl"))
        theory += parseFileAsTheory(Main::class.java.getResource("/Utils.pl"))
        return theory
    }
}