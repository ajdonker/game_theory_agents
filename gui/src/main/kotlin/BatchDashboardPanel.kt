
package gui

import org.knowm.xchart.XChartPanel
import org.knowm.xchart.XYChart
import org.knowm.xchart.XYChartBuilder
import java.awt.BorderLayout
import java.awt.Dimension
import java.awt.GridLayout
import kotlin.math.sqrt
import org.knowm.xchart.XYSeries
import org.knowm.xchart.style.markers.SeriesMarkers
import java.util.Locale
import javax.swing.*
import javax.swing.table.DefaultTableModel

data class BatchRound(
    val round: Int,
    val investment: Double?,
    val rentPct: Double?,
    val distance: Double?
)

data class BatchRunData(
    val config: ExperimentConfig,
    val rounds: List<BatchRound>
)

class BatchDashboardPanel : JPanel(BorderLayout(8, 8)) {
    private val progress = JProgressBar().apply {
        isStringPainted = true
    }

    private val statusLabel = JLabel("No batch started")

    private val tableModel = object : DefaultTableModel(
        arrayOf(
            "Run", "Run ID", "Seed", "Status",
            "Rounds", "Mean rent %", "Mean investment",
            "Early SD", "Late SD"
        ),
        0
    ) {
        override fun isCellEditable(row: Int, column: Int) = false
    }

    private val table = JTable(tableModel).apply {
        autoCreateRowSorter = false
        fillsViewportHeight = true
        setSelectionMode(ListSelectionModel.SINGLE_SELECTION)
    }

    private val chart: XYChart = XYChartBuilder()
        .width(800)
        .height(280)
        .title("Mean rent across completed runs")
        .xAxisTitle("Experiment number")
        .yAxisTitle("Mean rent (% optimum)")
        .build()

    private val chartPanel = XChartPanel(chart)

    private val chartX = mutableListOf<Double>()
    private val chartY = mutableListOf<Double>()
    private var chartSeriesAdded = false

    private val dampingChart: XYChart = XYChartBuilder()
        .width(800)
        .height(280)
        .title("Oscillation damping — early vs late")
        .xAxisTitle("Early investment SD")
        .yAxisTitle("Late investment SD")
        .build()

    private val dampingChartPanel = XChartPanel(dampingChart)

    private val earlySD = mutableListOf<Double>()
    private val lateSD = mutableListOf<Double>()

    private var dampingSeriesAdded = false

    private var experiments = emptyList<ExperimentConfig>()
    private var observations =
        emptyList<MutableMap<Int, BatchRound>>()

    private var currentIndex = -1

    init {
        dampingChart.addSeries(
            "No change (y = x)",
            listOf(0.0, 1.0),
            listOf(0.0, 1.0)
        ).setMarker(SeriesMarkers.NONE)

        val header = JPanel().apply {
            layout = BoxLayout(this, BoxLayout.Y_AXIS)
            add(progress)
            add(statusLabel)
        }
        // Stack the charts vertically.
        val charts = JPanel(GridLayout(2, 1, 0, 8)).apply {
            preferredSize = Dimension(800, 620)

            add(chartPanel)
            add(dampingChartPanel)
        }
        val split = JSplitPane(
            JSplitPane.VERTICAL_SPLIT,
            JScrollPane(table),
            JScrollPane(charts)
        ).apply {
            resizeWeight = 0.45
        }

        add(header, BorderLayout.NORTH)
        add(split, BorderLayout.CENTER)
    }

    fun prepare(configs: List<ExperimentConfig>) {
        require(configs.isNotEmpty())

        experiments = configs
        observations = List(configs.size) {
            mutableMapOf<Int, BatchRound>()
        }

        currentIndex = -1
        tableModel.rowCount = 0

        configs.forEachIndexed { index, config ->
            tableModel.addRow(
                arrayOf<Any>(
                    index + 1,
                    config.runId,
                    config.seed,
                    "Pending",
                    "0/${config.rounds}",
                    "-",
                    "-",
                    "-",
                    "-"
                )
            )
        }

        progress.minimum = 0
        progress.maximum = configs.size
        progress.value = 0
        progress.string = "0/${configs.size} completed"

        earlySD.clear()
        lateSD.clear()
        chartX.clear()
        chartY.clear()
        if (dampingSeriesAdded) {
            dampingChart.removeSeries("Independent runs")
            dampingSeriesAdded = false
        }
        if (chartSeriesAdded) {
            chart.removeSeries("Mean rent")
            chartSeriesAdded = false
        }
        dampingChart.updateXYSeries(
            "No change (y = x)",
            listOf(0.0, 1.0),
            listOf(0.0, 1.0),
            null
        )

        dampingChartPanel.repaint()
        chartPanel.repaint()

        statusLabel.text = "Ready: ${configs.size} runs"
    }

    fun startRun(index: Int) {
        require(index in experiments.indices)

        currentIndex = index
        val config = experiments[index]

        tableModel.setValueAt("Running", index, 3)

        statusLabel.text =
            "Running ${index + 1}/${experiments.size} " +
                    "| ID ${config.runId} | Seed ${config.seed}"

        table.setRowSelectionInterval(index, index)
        table.scrollRectToVisible(
            table.getCellRect(index, 0, true)
        )
    }

    fun record(event: SimulationEvent) {
        if (event !is SimulationEvent.RoundFinished) return
        if (currentIndex !in experiments.indices) return

        val data = observations[currentIndex]

        data[event.round] = BatchRound(
            round = event.round,
            investment = event.totalInvestment,
            rentPct = event.rentPct,
            distance = event.distanceToOptimum
        )

        val config = experiments[currentIndex]

        tableModel.setValueAt(
            "${data.size}/${config.rounds}",
            currentIndex,
            4
        )

        val meanRent = data.values
            .mapNotNull { it.rentPct }
            .takeIf { it.isNotEmpty() }
            ?.average()

        val meanInvestment = data.values
            .mapNotNull { it.investment }
            .takeIf { it.isNotEmpty() }
            ?.average()

        tableModel.setValueAt(
            format(meanRent), currentIndex, 5
        )
        tableModel.setValueAt(
            format(meanInvestment), currentIndex, 6
        )
    }

    fun finishRun(success: Boolean) {
        if (currentIndex !in experiments.indices) return

        val index = currentIndex

        tableModel.setValueAt(
            if (success) "Completed" else "Failed",
            index,
            3
        )

        if (success) {
            progress.value = index + 1
            progress.string =
                "${index + 1}/${experiments.size} completed"

            val meanRent = observations[index].values
                .mapNotNull { it.rentPct }
                .takeIf { it.isNotEmpty() }
                ?.average()

            if (meanRent != null) {
                chartX.add((index + 1).toDouble())
                chartY.add(meanRent)

                if (!chartSeriesAdded) {
                    chart.addSeries(
                        "Mean rent",
                        chartX.toList(),
                        chartY.toList()
                    )
                    chartSeriesAdded = true
                } else {
                    chart.updateXYSeries(
                        "Mean rent",
                        chartX.toList(),
                        chartY.toList(),
                        null
                    )
                }
                addDampingPoint(index)
                chartPanel.repaint()
            }
        }

        currentIndex = -1
    }

    fun finishBatch(message: String) {
        statusLabel.text = message
    }
    private fun standardDeviation(values: List<Double>): Double {
        require(values.size >= 2)

        val mean = values.average()

        val variance = values.sumOf {
            (it - mean) * (it - mean)
        } / (values.size - 1)

        return sqrt(variance)
    }

    private fun addDampingPoint(runIndex: Int) {
        // Total group investment in chronological order.
        val investments = observations[runIndex].values
            .sortedBy { it.round }
            .mapNotNull { it.investment }
            .filter { it.isFinite() }

        // Compare equal-length, non-overlapping windows.
        // For 300 rounds: first 50 and last 50.
        val window = minOf(50, investments.size / 2)

        if (window < 2) return

        val early = investments.take(window)
        val late = investments.takeLast(window)

        val earlyValue = standardDeviation(early)
        val lateValue = standardDeviation(late)
        tableModel.setValueAt(
            format(earlyValue), runIndex, 7
        )

        tableModel.setValueAt(
            format(lateValue), runIndex, 8
        )

        earlySD.add(earlyValue)
        lateSD.add(lateValue)
        
        // Adjust the reference diagonal to the data range.
        val maxValue = maxOf(
            1.0,
            (earlySD + lateSD).max() * 1.1
        )

        dampingChart.updateXYSeries(
            "No change (y = x)",
            listOf(0.0, maxValue),
            listOf(0.0, maxValue),
            null
        )

        if (!dampingSeriesAdded) {
            dampingChart.addSeries(
                "Independent runs",
                earlySD.toList(),
                lateSD.toList()
            ).apply {
                setXYSeriesRenderStyle(
                    XYSeries.XYSeriesRenderStyle.Scatter
                )
                setMarker(SeriesMarkers.CIRCLE)
            }

            dampingSeriesAdded = true
        } else {
            dampingChart.updateXYSeries(
                "Independent runs",
                earlySD.toList(),
                lateSD.toList(),
                null
            )
        }

        dampingChartPanel.repaint()
    }
    // Preserves every recorded round from every run.
    // Later batch plots can consume this directly.
    fun allRuns(): List<BatchRunData> =
        experiments.mapIndexed { index, config ->
            BatchRunData(
                config = config,
                rounds = observations[index].values
                    .sortedBy { it.round }
            )
        }

    private fun format(value: Double?): String =
        value?.let {
            String.format(Locale.US, "%.2f", it)
        } ?: "-"
}
