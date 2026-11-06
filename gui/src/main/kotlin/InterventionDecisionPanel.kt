
package gui

import java.awt.BorderLayout
import javax.swing.*
import javax.swing.table.DefaultTableModel

class InterventionDecisionPanel(
    private val detailArea: JTextArea
) : JPanel(BorderLayout(8, 8)) {

    private val model = object : DefaultTableModel(
        arrayOf(
            "Round", "Current", "Proposed", "Selected",
            "Mode age", "Optimal count",
            "Applied", "Success", "Planner issues"
        ), 0
    ) {
        override fun isCellEditable(row: Int, column: Int) = false

        override fun getColumnClass(column: Int): Class<*> =
            when (column) {
                0, 4, 5, 8 -> Integer::class.java
                else -> String::class.java
            }
    }

    private val table = JTable(model).apply {
        autoCreateRowSorter = true
        setSelectionMode(ListSelectionModel.SINGLE_SELECTION)
    }

    private val followLatest =
        JCheckBox("Follow latest decision", true)

    private val decisions =
        mutableMapOf<Int, SimulationEvent.InterventionDecision>()

    private val applied =
        mutableMapOf<Int, SimulationEvent.InterventionApplied>()

    private val plans =
        mutableMapOf<Int, MutableList<SimulationEvent.PlannerDecision>>()

    private val failures =
        mutableMapOf<Int, MutableList<SimulationEvent.PlannerFailed>>()

    private val rowByRound = mutableMapOf<Int, Int>()

    init {
        detailArea.isEditable = false
        detailArea.lineWrap = true
        detailArea.wrapStyleWord = true

        val split = JSplitPane(
            JSplitPane.VERTICAL_SPLIT,
            JScrollPane(table),
            JScrollPane(detailArea)
        ).apply {
            resizeWeight = 0.65
        }

        add(followLatest, BorderLayout.NORTH)
        add(split, BorderLayout.CENTER)

        table.selectionModel.addListSelectionListener {
            if (!it.valueIsAdjusting) {
                refreshDetails()
            }
        }

        reset()
    }

    private fun rowData(
        e: SimulationEvent.InterventionDecision
    ): Array<Any?> {
        val execution = applied[e.round]

        return arrayOf(
            e.round,
            e.currentMode,
            e.proposedMode,
            e.selectedMode,
            e.modeAge,
            e.optimalCount,
            execution?.mode ?: "-",
            execution?.success?.toString() ?: "-",
            failures[e.round]?.size ?: 0
        )
    }

    fun recordDecision(e: SimulationEvent.InterventionDecision) {
        decisions[e.round] = e

        val existing = rowByRound[e.round]

        val modelRow = if (existing == null) {
            val index = model.rowCount
            model.addRow(rowData(e))
            rowByRound[e.round] = index
            index
        } else {
            updateRow(existing, e)
            existing
        }

        if (followLatest.isSelected) {
            selectModelRow(modelRow)
        }

        refreshDetails()
    }

    fun recordApplied(e: SimulationEvent.InterventionApplied) {
        applied[e.round] = e
        updateRound(e.round)
    }

    fun recordPlan(e: SimulationEvent.PlannerDecision) {
        plans.getOrPut(e.round) { mutableListOf() }.add(e)
        refreshDetails()
    }

    fun recordFailure(e: SimulationEvent.PlannerFailed) {
        failures.getOrPut(e.round) { mutableListOf() }.add(e)
        updateRound(e.round)
    }

    private fun updateRound(round: Int) {
        val decision = decisions[round] ?: return
        val row = rowByRound[round] ?: return

        updateRow(row, decision)
        refreshDetails()
    }

    private fun updateRow(
        row: Int,
        e: SimulationEvent.InterventionDecision
    ) {
        rowData(e).forEachIndexed { column, value ->
            model.setValueAt(value, row, column)
        }
    }

    private fun selectModelRow(modelRow: Int) {
        val viewRow = table.convertRowIndexToView(modelRow)
        if (viewRow < 0) return

        table.selectionModel.setSelectionInterval(
            viewRow, viewRow
        )

        table.scrollRectToVisible(
            table.getCellRect(viewRow, 0, true)
        )
    }

    private fun refreshDetails() {
        val viewRow = table.selectedRow

        if (viewRow < 0) {
            detailArea.text = "Select a decision to inspect it."
            return
        }

        val modelRow = table.convertRowIndexToModel(viewRow)
        val round = model.getValueAt(modelRow, 0) as Int

        val decision = decisions[round] ?: return
        val execution = applied[round]

        detailArea.text = buildString {
            appendLine("ROUND $round")
            appendLine()
            appendLine("Current mode: ${decision.currentMode}")
            appendLine("STRIPS proposal: ${decision.proposedMode}")
            appendLine("After stability gate: ${decision.selectedMode}")
            appendLine("Mode age: ${decision.modeAge}")
            appendLine("Optimal count: ${decision.optimalCount}")

            appendLine()
            appendLine("EXECUTION")
            if (execution == null) {
                appendLine("No execution confirmation received")
            } else {
                appendLine("Applied: ${execution.mode}")
                appendLine("Success: ${execution.success}")
            }

            val roundPlans = plans[round].orEmpty()
            if (roundPlans.isNotEmpty()) {
                appendLine()
                appendLine("REPORTED PLANS")

                roundPlans.forEach { plan ->
                    appendLine("Mode label: ${plan.selectedMode}")
                    appendLine(
                        "Symbolic state: " +
                                if (plan.symbolicState.isEmpty())
                                    "Not supplied"
                                else plan.symbolicState.joinToString()
                    )
                    appendLine(
                        "Actions: ${plan.plan.joinToString(" -> ")}"
                    )
                }
            }

            val roundFailures = failures[round].orEmpty()
            if (roundFailures.isNotEmpty()) {
                appendLine()
                appendLine("PLANNER FAILURES")

                roundFailures.forEach {
                    appendLine("- ${it.reason}")
                }
            }
        }
    }

    fun reset() {
        model.rowCount = 0

        decisions.clear()
        applied.clear()
        plans.clear()
        failures.clear()
        rowByRound.clear()

        followLatest.isSelected = true
        detailArea.text = "No intervention decisions yet."
    }
}
