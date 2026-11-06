
package gui
import org.knowm.xchart.XYSeries
import org.knowm.xchart.style.markers.SeriesMarkers
import java.awt.Color
import org.knowm.xchart.XYChart
import org.knowm.xchart.XYChartBuilder
import org.knowm.xchart.XChartPanel
import java.awt.BorderLayout
import java.awt.Dimension
import java.awt.GridLayout
import java.util.TreeMap
import javax.swing.JLabel
import javax.swing.JPanel
import javax.swing.JScrollPane
import javax.swing.JTextArea

class LiveChartsPanel : JPanel(BorderLayout()) {

    private val investment = TreeMap<Int, Double>()
    private val rent = TreeMap<Int, Double>()
    private val distance = TreeMap<Int, Double>()

    private val chartContainer = JPanel(GridLayout(3, 1, 0, 10))

    private lateinit var investmentChart: XYChart
    private lateinit var rentChart: XYChart
    private lateinit var distanceChart: XYChart

    private lateinit var investmentPanel: XChartPanel<XYChart>
    private lateinit var rentPanel: XChartPanel<XYChart>
    private lateinit var distancePanel: XChartPanel<XYChart>

    private var investmentAdded = false
    private var optimumAdded = false
    private var rentAdded = false
    private var distanceAdded = false

    private val activeModes = sortedMapOf<Int, String>()
    private val investmentModeSeries = mutableSetOf<String>()
    private val rentModeSeries = mutableSetOf<String>()

    private fun modeColor(mode: String): Color =
        when (mode.lowercase()) {
            "none" -> Color(130, 130, 130)
            "centralized" -> Color(70, 125, 215)
            "decentralized" -> Color(40, 155, 100)
            "coalition" -> Color(193, 139, 48)
            else -> Color.DARK_GRAY
        }
    private val modeHistoryArea = JTextArea(4, 40).apply {
        isEditable = false
    }

    private val optimum = 36.0

    init {
        add(JScrollPane(chartContainer), BorderLayout.CENTER)
        val modeHistoryPanel = JPanel(BorderLayout())

        modeHistoryPanel.add(
            JLabel("Active Intervention History"),
            BorderLayout.NORTH
        )

        modeHistoryPanel.add(
            JScrollPane(modeHistoryArea),
            BorderLayout.CENTER
        )

        add(modeHistoryPanel, BorderLayout.SOUTH)
        reset()
    }

    private fun createChart(title: String, yTitle: String): XYChart =
        XYChartBuilder()
            .width(800)
            .height(240)
            .title(title)
            .xAxisTitle("Round")
            .yAxisTitle(yTitle)
            .build()

    private fun createPanel(chart: XYChart): XChartPanel<XYChart> =
        XChartPanel(chart).apply {
            preferredSize = Dimension(760, 240)
        }

    fun addRound(event: SimulationEvent.RoundFinished) {
        event.totalInvestment?.let {
            investment[event.round] = it
        }

        event.rentPct?.let {
            rent[event.round] = it
        }

        event.distanceToOptimum?.let {
            distance[event.round] = it
        }

        investmentAdded = updateSeries(
            investmentChart,
            investmentPanel,
            "Total investment",
            investment,
            investmentAdded
        )

        if (investment.isNotEmpty()) {
            val first = investment.firstKey()
            val last = maxOf(investment.lastKey(), first + 1)

            val reference = sortedMapOf(
                first to optimum,
                last to optimum
            )

            optimumAdded = updateSeries(
                investmentChart,
                investmentPanel,
                "Social optimum",
                reference,
                optimumAdded
            )
        }

        rentAdded = updateSeries(
            rentChart,
            rentPanel,
            "Rent %",
            rent,
            rentAdded
        )

        distanceAdded = updateSeries(
            distanceChart,
            distancePanel,
            "Distance",
            distance,
            distanceAdded
        )

        refreshModeOverlays()
    }

    private fun updateSeries(
        chart: XYChart,
        panel: XChartPanel<XYChart>,
        name: String,
        points: Map<Int, Double>,
        alreadyAdded: Boolean
    ): Boolean {
        if (points.isEmpty()) return alreadyAdded

        val x = points.keys.map { it.toDouble() }
        val y = points.values.toList()

        if (alreadyAdded) {
            chart.updateXYSeries(name, x, y, null)
        } else {
            chart.addSeries(name, x, y)
        }

        panel.revalidate()
        panel.repaint()

        return true
    }

    fun reset() {
        investment.clear()
        rent.clear()
        distance.clear()
        activeModes.clear()
        investmentModeSeries.clear()
        rentModeSeries.clear()

        investmentAdded = false
        optimumAdded = false
        rentAdded = false
        distanceAdded = false

        investmentChart = createChart(
            "Group investment", "Investment"
        )
        rentChart = createChart(
            "Rent performance", "Rent (%)"
        )
        distanceChart = createChart(
            "Distance from social optimum", "Distance"
        )
        modeHistoryArea.text = ""
        investmentPanel = createPanel(investmentChart)
        rentPanel = createPanel(rentChart)
        distancePanel = createPanel(distanceChart)

        chartContainer.removeAll()
        chartContainer.add(investmentPanel)
        chartContainer.add(rentPanel)
        chartContainer.add(distancePanel)

        chartContainer.revalidate()
        chartContainer.repaint()
    }
    fun addMode(round: Int, mode: String) {
        activeModes[round] = mode

        val entries = activeModes.entries.toList()

        // Display only rounds when the mode changes
        val changes = entries.filterIndexed { index, entry ->
            index == 0 || entry.value != entries[index - 1].value
        }

        modeHistoryArea.text = changes.joinToString("\n") {
            "Round ${it.key}: ${it.value}"
        }
        refreshModeOverlays()
    }

    private fun updateModeOverlay(
        mode: String,
        values: Map<Int, Double>,
        chart: XYChart,
        panel: XChartPanel<XYChart>,
        registered: MutableSet<String>
    ) {
        val observations = values.entries.filter {
            activeModes[it.key]?.lowercase() == mode
        }

        if (observations.isEmpty()) return

        val x = observations.map { it.key.toDouble() }
        val y = observations.map { it.value }

        val seriesName = "Active: $mode"

        if (seriesName in registered) {
            chart.updateXYSeries(seriesName, x, y, null)
        } else {
            chart.addSeries(seriesName, x, y).apply {
                setXYSeriesRenderStyle(
                    XYSeries.XYSeriesRenderStyle.Scatter
                )
                setMarker(SeriesMarkers.CIRCLE)
                setMarkerColor(modeColor(mode))
                setLineColor(modeColor(mode))
            }

            registered.add(seriesName)
        }

        panel.repaint()
    }

    private fun refreshModeOverlays() {
        val modes = activeModes.values
            .map { it.lowercase() }
            .distinct()

        for (mode in modes) {
            updateModeOverlay(
                mode,
                investment,
                investmentChart,
                investmentPanel,
                investmentModeSeries
            )

            updateModeOverlay(
                mode,
                rent,
                rentChart,
                rentPanel,
                rentModeSeries
            )
        }
    }

}
