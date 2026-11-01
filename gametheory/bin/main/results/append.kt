package results

import jason.asSemantics.DefaultInternalAction
import jason.asSemantics.TransitionSystem
import jason.asSemantics.Unifier
import jason.asSyntax.Term
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardOpenOption

class append : DefaultInternalAction() {

    override fun getMinArgs(): Int = 2
    override fun getMaxArgs(): Int = 50

    override fun execute(
        ts: TransitionSystem,
        un: Unifier,
        args: Array<Term>
    ): Any {
        val filename = args[0].toString().trim('"')

        val row = args
            .drop(1)
            .joinToString(",") {
                csvEscape(it.toString().trim('"'))
            }

        synchronized(lock) {
            val path = Path.of(filename)

            path.parent?.let {
                Files.createDirectories(it)
            }

            Files.writeString(
                path,
                row + System.lineSeparator(),
                StandardOpenOption.CREATE,
                StandardOpenOption.APPEND
            )
        }

        return true
    }

    private fun csvEscape(value: String): String {
        return if (
            value.contains(",") ||
            value.contains("\"") ||
            value.contains("\n")
        ) {
            "\"" + value.replace("\"", "\"\"") + "\""
        } else {
            value
        }
    }

    companion object {
        private val lock = Any()
    }

}    