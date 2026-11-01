package gui
import java.awt.BorderLayout
import java.awt.GridLayout
import javax.swing.*
import javax.swing.border.EmptyBorder

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
        val centerPanel = JPanel(BorderLayout(10, 10))
        centerPanel.add(form, BorderLayout.NORTH)
        centerPanel.add(consolePanel, BorderLayout.CENTER)
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

            resetProgress(config.rounds)
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
}
