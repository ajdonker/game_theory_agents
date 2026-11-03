package gui
import java.awt.BorderLayout
import java.awt.GridLayout
import javax.swing.*
import javax.swing.border.EmptyBorder
import javax.swing.table.DefaultTableModel

class SimulationFrame(
    private val onStart: (ExperimentConfig) -> Unit
) : JFrame("CPR Multi-Agent Simulation") {

    private val runIdSpinner = JSpinner(
        SpinnerNumberModel(1, 1, 1000000, 1)
    )

    private val seedSpinner = JSpinner(
        SpinnerNumberModel(42L, 0L, Long.MAX_VALUE, 1L)
    )

    private val roundsSpinner = JSpinner(
        SpinnerNumberModel(300, 1, 1000000, 1)
    )

    private val scenarioBox = JComboBox(
        Scenario.entries.toTypedArray()
    )

    private val progressBar = JProgressBar(0, 100).apply {
        isStringPainted = true
        string = "Round 0 / 100"
    }

    private val startButton = JButton("Start Simulation")
    private val statusLabel = JLabel("Ready")
    private val logArea = JTextArea(12, 55).apply {
        isEditable = false
        lineWrap = false
        font = java.awt.Font("Monospaced", java.awt.Font.PLAIN, 12)
    }
    private val metricsLabel =
        JLabel("Investment: - | Rent: - | Distance: -")

    private val agentTableModel = object : DefaultTableModel(
        arrayOf("Agent", "Bid", "Payoff", "Strategy"), 0
    ) {
        override fun isCellEditable(
            row: Int, column: Int
        ) = false
    }

    private val agentTable = JTable(agentTableModel)

    private val plannerArea = JTextArea().apply {
        isEditable = false
    }

    private val interventionArea = JTextArea().apply {
        isEditable = false
    }

    private val coalitionArea = JTextArea().apply {
        isEditable = false
    }

    private val summaryArea = JTextArea().apply {
        isEditable = false
    }

    private var displayedAgentRound = -1

    private var sumRentPct = 0.0
    private var sumDistance = 0.0
    private var metricRoundCount = 0
    init {
        defaultCloseOperation = EXIT_ON_CLOSE
        setSize(750, 600)
        setLocationRelativeTo(null)

        scenarioBox.selectedItem = Scenario.ADAPTIVE

        // Configuration fields
        val form = JPanel(GridLayout(4, 2, 12, 12))

        form.add(JLabel("Run ID:"))
        form.add(runIdSpinner)

        form.add(JLabel("Seed:"))
        form.add(seedSpinner)

        form.add(JLabel("Rounds:"))
        form.add(roundsSpinner)

        form.add(JLabel("Scenario:"))
        form.add(scenarioBox)

        // Bottom panel
        val bottom = JPanel(BorderLayout(10, 10))
        bottom.add(startButton, BorderLayout.NORTH)
        bottom.add(statusLabel, BorderLayout.SOUTH)
        bottom.add(progressBar, BorderLayout.CENTER)

        // Main layout
        val content = JPanel(BorderLayout(15, 15))
        content.border = EmptyBorder(20, 20, 20, 20)

        content.add(
            JLabel("Experiment Configuration"),
            BorderLayout.NORTH
        )

        //content.add(form, BorderLayout.CENTER)
        val consolePanel = JPanel(BorderLayout(5, 5))
        consolePanel.add(JLabel("Live Sim Output:"), BorderLayout.NORTH)
        consolePanel.add(JScrollPane(logArea), BorderLayout.CENTER)
        val tabs = JTabbedPane().apply {
            addTab("Console", consolePanel)
            addTab("Agents", JScrollPane(agentTable))
            addTab("Planner", JScrollPane(plannerArea))
            addTab("Interventions", JScrollPane(interventionArea))
            addTab("Coalitions", JScrollPane(coalitionArea))
            addTab("Summary", JScrollPane(summaryArea))
        }

        val configurationPanel = JPanel(BorderLayout(8, 8))
        configurationPanel.add(form, BorderLayout.NORTH)
        configurationPanel.add(metricsLabel, BorderLayout.SOUTH)

        val centerPanel = JPanel(BorderLayout(10, 10))
        centerPanel.add(configurationPanel, BorderLayout.NORTH)
        centerPanel.add(tabs, BorderLayout.CENTER)

        content.add(centerPanel, BorderLayout.CENTER)
        content.add(bottom, BorderLayout.SOUTH)

        add(content)

        startButton.addActionListener {
            startSimulation()
        }
    }
    fun setStatus(message: String) {
        statusLabel.text = message
    }
    private fun startSimulation() {
        try {
            // Commit any values currently being edited
            runIdSpinner.commitEdit()
            seedSpinner.commitEdit()
            roundsSpinner.commitEdit()

            val config = ExperimentConfig(
                runId = (runIdSpinner.value as Number).toInt(),
                seed = (seedSpinner.value as Number).toLong(),
                rounds = (roundsSpinner.value as Number).toInt(),
                scenario = scenarioBox.selectedItem as Scenario
            )

            resetForNewRun(config)
            onStart(config)
            setStatus("Configuration submitted: Run ${config.runId}")

        } catch (e: Exception) {
            JOptionPane.showMessageDialog(
                this,
                e.message,
                "Cannot start",
                JOptionPane.ERROR_MESSAGE
            )
        }
    }
    fun appendLog(line: String) {
        logArea.append(line + "\n")
        if(logArea.document.length > 100000) {
            logArea.replaceRange("",0, 20_000)
        }
        logArea.caretPosition = logArea.document.length
    }
    fun resetProgress(rounds: Int) {
        progressBar.maximum = rounds
        progressBar.value = 0
        progressBar.string = "Round 0 / $rounds"
    }
    fun updateProgress(round: Int) {
        progressBar.value = round.coerceIn(0, progressBar.maximum)
        progressBar.string = "Round ${progressBar.value} / ${progressBar.maximum}"
    }


    fun handleEvent(event: SimulationEvent) {
        when (event) {

            // 1. Group-level results
            is SimulationEvent.RoundFinished -> {
                updateProgress(event.round)

                metricsLabel.text =
                    "Investment: ${event.totalInvestment} | " +
                            "Rent: ${event.rentPct}% | " +
                            "Distance: ${event.distanceToOptimum}"

                if (event.rentPct != null &&
                    event.distanceToOptimum != null
                ) {
                    sumRentPct += event.rentPct
                    sumDistance += event.distanceToOptimum
                    metricRoundCount++
                }
            }

            // 2. Individual agent results
            is SimulationEvent.AgentResult -> {

                if (displayedAgentRound != event.round) {
                    displayedAgentRound = event.round
                    agentTableModel.rowCount = 0
                }

                agentTableModel.addRow(
                    arrayOf<Any?>(
                        event.agent,
                        event.bid,
                        event.payoff,
                        event.strategy
                    )
                )
            }

            // 3. STRIPS symbolic planning
            is SimulationEvent.PlannerDecision -> {
                plannerArea.append(
                    "ROUND ${event.round}\n" +
                            "Selected mode: ${event.selectedMode}\n" +
                            "Symbolic state: ${event.symbolicState}\n" +
                            "Plan: ${event.plan}\n" +
                            "----------------------------\n"
                )
            }

            // 4. Proposed vs gated intervention
            is SimulationEvent.InterventionDecision -> {
                interventionArea.append(
                    "ROUND ${event.round}\n" +
                            "Current: ${event.currentMode}\n" +
                            "Proposed: ${event.proposedMode}\n" +
                            "Selected: ${event.selectedMode}\n" +
                            "Mode age: ${event.modeAge}\n" +
                            "Optimal count: ${event.optimalCount}\n" +
                            "----------------------------\n"
                )
            }

            // 5. Actual intervention execution
            is SimulationEvent.InterventionApplied -> {
                interventionArea.append(
                    "ROUND ${event.round}\n" +
                            "APPLIED: ${event.mode}\n" +
                            "SUCCESS: ${event.success}\n" +
                            "----------------------------\n"
                )
            }

            // 6. Coalition membership changes
            is SimulationEvent.CoalitionChanged -> {
                coalitionArea.append(
                    "ROUND ${event.round}\n" +
                            "Coalition: ${event.coalitionId}\n" +
                            "Change: ${event.change}\n" +
                            "Members: ${event.members}\n" +
                            "----------------------------\n"
                )
            }

            // 7. Planner failures
            is SimulationEvent.PlannerFailed -> {
                plannerArea.append(
                    "ROUND ${event.round}: PLANNER FAILED\n" +
                            "Reason: ${event.reason}\n" +
                            "----------------------------\n"
                )
            }

            // 8. Experiment completion
            is SimulationEvent.SimulationFinished -> {

                val meanRent = if (metricRoundCount > 0)
                    sumRentPct / metricRoundCount
                else null

                val meanDistance = if (metricRoundCount > 0)
                    sumDistance / metricRoundCount
                else null

                summaryArea.text = """
                SIMULATION FINISHED

                Final round: ${event.round}
                Observed rounds: $metricRoundCount

                Mean rent: ${meanRent ?: "N/A"}%
                Mean distance: ${meanDistance ?: "N/A"}

                Check the generated CSV files
                for detailed experimental results.
            """.trimIndent()

                setStatus(
                    "Simulation finished after ${event.round} rounds"
                )
            }
        }
    }

    private fun resetForNewRun(config: ExperimentConfig) {

        resetProgress(config.rounds)

        logArea.text = ""
        plannerArea.text = ""
        interventionArea.text = ""
        coalitionArea.text = ""
        summaryArea.text = ""

        agentTableModel.rowCount = 0
        displayedAgentRound = -1

        sumRentPct = 0.0
        sumDistance = 0.0
        metricRoundCount = 0

        metricsLabel.text =
            "Investment: - | Rent: - | Distance: -"

        statusLabel.text =
            "Launching ${config.scenario} | Run ${config.runId}"
    }
}
