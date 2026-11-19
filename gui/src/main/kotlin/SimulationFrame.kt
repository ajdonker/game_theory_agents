package gui
import java.awt.BorderLayout
import java.awt.GridLayout
import javax.swing.*
import javax.swing.border.EmptyBorder
import javax.swing.table.DefaultTableModel

class SimulationFrame(
    private val onStart: (ExperimentConfig) -> Unit
) : JFrame("CPR Multi-Agent Simulation") {

    internal val progressValueForTest: Int
        get() = progressBar.value

    internal val metricsTextForTest: String
        get() = metricsLabel.text

    internal val agentRowCountForTest: Int
        get() = agentTableModel.rowCount

    internal val interventionTextForTest: String
        get() = interventionArea.text

    private val runIdSpinner = JSpinner(
        SpinnerNumberModel(1, 1, 1000000, 1)
    )

    private val seedSpinner = JSpinner(
        SpinnerNumberModel(42L, 0L, Long.MAX_VALUE, 1L)
    )

    private val roundsSpinner = JSpinner(
        SpinnerNumberModel(300, 1, 1000000, 1)
    )
    private val executionModeBox = JComboBox(
        arrayOf("Single run", "Batch runs")
    )

    private val batchCountSpinner = JSpinner(
        SpinnerNumberModel(30, 1, 1000, 1)
    )

    private val batchFirstRunIdSpinner = JSpinner(
        SpinnerNumberModel(1, 1, 1_000_000, 1)
    )

    private val batchFirstSeedSpinner = JSpinner(
        SpinnerNumberModel(42L, 0L, Long.MAX_VALUE, 1L)
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
    private val activeModeLabel =
        JLabel("Active intervention: -")
    private val agentTableModel = object : DefaultTableModel(
        arrayOf("Round","Agent", "Bid", "Payoff", "Strategy"), 0
    ) {
        override fun isCellEditable(
            row: Int, column: Int
        ) = false
    }

    private val agentTable = JTable(agentTableModel).apply {
        autoCreateRowSorter = true
    }

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
    private val liveChartsPanel = LiveChartsPanel()

    val batchPanel = BatchDashboardPanel()

    private val interventionPanel =
        InterventionDecisionPanel(interventionArea)

    private var sumRentPct = 0.0
    private var sumDistance = 0.0
    private var metricRoundCount = 0
    init {
        
        progressBar.name = "progressBar"
        metricsLabel.name = "metricsLabel"
        agentTable.name = "agentTable"
        plannerArea.name = "plannerArea"
        interventionArea.name = "interventionArea"
        coalitionArea.name = "coalitionArea"
        summaryArea.name = "summaryArea"
        startButton.name = "startButton"
        roundsSpinner.name = "roundsSpinner"

        defaultCloseOperation = EXIT_ON_CLOSE
        setSize(750, 600)
        setLocationRelativeTo(null)

        scenarioBox.selectedItem = Scenario.ADAPTIVE

        // Configuration fields

        val sharedForm = JPanel(GridLayout(2, 2, 12, 8)).apply {
            add(JLabel("Scenario:"))
            add(scenarioBox)

            add(JLabel("Rounds per run:"))
            add(roundsSpinner)
        }

        val singleForm = JPanel(GridLayout(2, 2, 12, 8)).apply {
            add(JLabel("Run ID:"))
            add(runIdSpinner)

            add(JLabel("Seed:"))
            add(seedSpinner)
        }

        val batchForm = JPanel(GridLayout(3, 2, 12, 8)).apply {
            add(JLabel("Number of runs:"))
            add(batchCountSpinner)

            add(JLabel("First run ID:"))
            add(batchFirstRunIdSpinner)

            add(JLabel("First seed:"))
            add(batchFirstSeedSpinner)
        }

        // Only one form is visible at a time.
        val modeCards = JPanel(java.awt.CardLayout()).apply {
            add(singleForm, "single")
            add(batchForm, "batch")
        }

        val modeSelector = JPanel(
            java.awt.FlowLayout(java.awt.FlowLayout.LEFT, 0, 4)
        ).apply {
            add(JLabel("Execution mode: "))
            add(executionModeBox)
        }

        // Switch the visible inputs and Start button text.
        executionModeBox.addActionListener {
            val mode = if (isBatchMode()) "batch" else "single"

            (modeCards.layout as java.awt.CardLayout).show(
                modeCards,
                mode
            )

            startButton.text = if (isBatchMode()) {
                "Start Batch"
            } else {
                "Start Simulation"
            }
        }

        // Top configuration controls.
        val configControls = JPanel().apply {
            layout = BoxLayout(this, BoxLayout.Y_AXIS)

            add(sharedForm)
            add(modeSelector)
            add(modeCards)
            add(startButton)
        }


        // Bottom panel
        val bottom = JPanel(BorderLayout(10, 10))
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
            addTab("Batch",batchPanel)
            addTab("Charts", liveChartsPanel)
            addTab("Agents", JScrollPane(agentTable))
            addTab("Planner", JScrollPane(plannerArea))
            addTab("Interventions", interventionPanel)
            addTab("Coalitions", JScrollPane(coalitionArea))
            addTab("Summary", JScrollPane(summaryArea))
            addTab("Console", consolePanel)
        }

        val metricsPanel = JPanel(GridLayout(2,1))
        metricsPanel.add(metricsLabel)
        metricsPanel.add(activeModeLabel)

        val configurationPanel = JPanel(BorderLayout(8, 8))
        configurationPanel.add(configControls, BorderLayout.NORTH)
        configurationPanel.add(metricsPanel, BorderLayout.SOUTH)

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
            roundsSpinner.commitEdit()

            val batchMode = isBatchMode()

            if (batchMode) {
                batchCountSpinner.commitEdit()
                batchFirstRunIdSpinner.commitEdit()
                batchFirstSeedSpinner.commitEdit()
            } else {
                runIdSpinner.commitEdit()
                seedSpinner.commitEdit()
            }

            val config = ExperimentConfig(
                runId = if (batchMode) {
                    (batchFirstRunIdSpinner.value as Number).toInt()
                } else {
                    (runIdSpinner.value as Number).toInt()
                },
                seed = if (batchMode) {
                    (batchFirstSeedSpinner.value as Number).toLong()
                } else {
                    (seedSpinner.value as Number).toLong()
                },
                rounds = (roundsSpinner.value as Number).toInt(),
                scenario = scenarioBox.selectedItem as Scenario
            )

            onStart(config)

        } catch (e: Exception) {
            JOptionPane.showMessageDialog(
                this,
                e.message,
                "Cannot start",
                JOptionPane.ERROR_MESSAGE
            )
        }
    }

    fun isBatchMode(): Boolean =
        executionModeBox.selectedIndex == 1

    fun readBatchConfig(): BatchConfig {
        require(isBatchMode()) {
            "Batch mode is not selected"
        }

        batchCountSpinner.commitEdit()
        batchFirstRunIdSpinner.commitEdit()
        batchFirstSeedSpinner.commitEdit()

        return BatchConfig(
            count = (batchCountSpinner.value as Number).toInt(),
            firstRunId = (batchFirstRunIdSpinner.value as Number).toInt(),
            firstSeed = (batchFirstSeedSpinner.value as Number).toLong()
        )
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
                liveChartsPanel.addRound(event)

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

                agentTableModel.addRow(
                    arrayOf<Any?>(
                        event.round,
                        event.agent,
                        event.bid,
                        event.payoff,
                        event.strategy
                    )
                )
            }

            // 3. STRIPS symbolic planning
            is SimulationEvent.PlannerDecision -> {
                interventionPanel.recordPlan(event)
                plannerArea.append(
                    "Round ${event.round}\n" +
                            "Reported mode: ${event.selectedMode}\n" +
                            "State: ${event.symbolicState}\n" +
                            "Plan: ${event.plan}\n\n"
                )
            }

            // 4. Proposed vs gated intervention
            is SimulationEvent.InterventionDecision -> {
                interventionPanel.recordDecision(event)
            }

            // 5. Actual intervention execution
            is SimulationEvent.InterventionApplied -> {
                interventionPanel.recordApplied(event)
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
                interventionPanel.recordFailure(event)
                plannerArea.append(
                    "ROUND ${event.round}: PLANNER FAILED\n" +
                            "Reason: ${event.reason}\n" +
                            "----------------------------\n"
                )
            }
            // 8. Active mode updates
            is SimulationEvent.ModeActive -> {
                activeModeLabel.text =
                    "Round ${event.round} | Active: ${event.mode}"

                liveChartsPanel.addMode(
                    event.round, event.mode
                )
            }

            // 9. Experiment completion
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

    fun resetForNewRun(config: ExperimentConfig) {

        resetProgress(config.rounds)
        liveChartsPanel.reset()
        interventionPanel.reset()

        logArea.text = ""
        plannerArea.text = ""
        interventionArea.text = ""
        coalitionArea.text = ""
        summaryArea.text = ""
        activeModeLabel.text = "Active intervention: -"
        agentTableModel.rowCount = 0

        sumRentPct = 0.0
        sumDistance = 0.0
        metricRoundCount = 0

        metricsLabel.text =
            "Investment: - | Rent: - | Distance: -"

        statusLabel.text =
            "Launching ${config.scenario} | Run ${config.runId}"
    }
}
