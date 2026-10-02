from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt

PROJECT = Path(__file__).resolve().parent.parent

RESULTS = PROJECT / "results"
PLOTS = RESULTS / "plots"

PLOTS.mkdir(parents=True, exist_ok=True)

RUN_ID = 3
SEED = 42

SINGLE_RUN_ID = 1

# ---------------------------------------------------------
# Read data
# ---------------------------------------------------------

rounds = pd.read_csv(
    RESULTS / "rounds.csv",
    header=None,
    names=[
        "run_id",
        "seed",
        "round",
        "total_bid",
        "average_bid",
        "group_rent",
        "rent_pct"
    ]
)

agents = pd.read_csv(
    RESULTS / "agents.csv",
    header=None,
    names=[
        "run_id",
        "seed",
        "round",
        "agent",
        "strategy",
        "bid",
        "market1",
        "market2",
        "payoff"
    ]
)

rounds_all = rounds.copy()
agents_all = agents.copy()
# # Only one experimental run
# rounds = rounds[
#     (rounds["run_id"] == RUN_ID) &
#     (rounds["seed"] == SEED)
# ]

# agents = agents[
#     (agents["run_id"] == RUN_ID) &
#     (agents["seed"] == SEED)
# ]
rounds = rounds_all[
    rounds_all["run_id"] == SINGLE_RUN_ID
].copy()

agents = agents_all[
    agents_all["run_id"] == SINGLE_RUN_ID
].copy()

SEED = int(rounds["seed"].iloc[0])

agent_order = sorted(agents["agent"].unique())
strategy_order = sorted(agents["strategy"].unique())


strategy_to_id = {
    strategy: i for i, strategy in enumerate(strategy_order)
}

agents["strategy_id"] = agents["strategy"].map(strategy_to_id)

# ---------------------------------------------------------
# Figure 1: Group rent as % optimum
# ---------------------------------------------------------

plt.figure(figsize=(10, 5))

plt.plot(
    rounds["round"],
    rounds["rent_pct"]
)

plt.axhline(
    100,
    linestyle="--",
    label="Social optimum"
)

plt.xlabel("Round")
plt.ylabel("Group rent (% of optimum)")
plt.title("Group performance over time")
plt.legend()
plt.tight_layout()

plt.savefig(
    PLOTS / "group_rent_pct.png",
    dpi=300
)

plt.close()


# ---------------------------------------------------------
# Figure 2: Total Market 2 investment
# ---------------------------------------------------------

plt.figure(figsize=(10, 5))

plt.plot(
    rounds["round"],
    rounds["total_bid"]
)

# Social optimum
plt.axhline(
    36,
    linestyle="--",
    label="Social optimum (36)"
)

# Nash equilibrium
plt.axhline(
    64,
    linestyle=":",
    label="Nash equilibrium (64)"
)

plt.xlabel("Round")
plt.ylabel("Total Market 2 investment")
plt.title("Group Market 2 investment over time")
plt.legend()
plt.tight_layout()

plt.savefig(
    PLOTS / "group_investment.png",
    dpi=300
)

plt.close()


# ---------------------------------------------------------
# Figure 3: Individual agent bids
# ---------------------------------------------------------

plt.figure(figsize=(11, 6))

for agent, data in agents.groupby("agent"):
    data = data.sort_values("round")

    plt.plot(
        data["round"],
        data["bid"],
        label=agent
    )

plt.xlabel("Round")
plt.ylabel("Market 2 bid")
plt.title("Individual Market 2 bids")
plt.ylim(0, 10)
plt.legend()
plt.tight_layout()

plt.savefig(
    PLOTS / "individual_bids.png",
    dpi=300
)

plt.close()


print(f"Plots written to {PLOTS}")


# ---------------------------------------------------------
# Figure 4: Heatmap
# ---------------------------------------------------------

heatmap = (
    agents
    .pivot(index="agent", columns="round", values="strategy_id")
    .reindex(agent_order)
)

plt.figure(figsize=(14, 4))
plt.imshow(
    heatmap,
    aspect="auto",
    interpolation="nearest"
)

plt.yticks(range(len(agent_order)), agent_order)
plt.xlabel("Round")
plt.ylabel("Agent")
plt.title("Current strategy followed by each agent")

cbar = plt.colorbar()
cbar.set_ticks(range(len(strategy_order)))
cbar.set_ticklabels(strategy_order)

plt.tight_layout()
plt.savefig(PLOTS / "strategy_heatmap.png", dpi=300)
plt.close()


# ---------------------------------------------------------
# Figure 5: Heatmap of strategy families
# ---------------------------------------------------------

def strategy_family(s: str) -> str:
    if s.startswith("total_return"):
        return "total_return"
    if s.startswith("unit_return"):
        return "unit_return"
    if s.startswith("group_average"):
        return "group_average"
    return "other"

agents["family"] = agents["strategy"].apply(strategy_family)

family_order = ["total_return", "unit_return", "group_average"]
family_to_id = {name: i for i, name in enumerate(family_order)}

agents["family_id"] = agents["family"].map(family_to_id)

family_heatmap = (
    agents
    .pivot(index="agent", columns="round", values="family_id")
    .reindex(agent_order)
)

plt.figure(figsize=(14, 4))
plt.imshow(
    family_heatmap,
    aspect="auto",
    interpolation="nearest"
)

plt.yticks(range(len(agent_order)), agent_order)
plt.xlabel("Round")
plt.ylabel("Agent")
plt.title("Strategy family followed by each agent")

cbar = plt.colorbar()
cbar.set_ticks(range(len(family_order)))
cbar.set_ticklabels(family_order)

plt.tight_layout()
plt.savefig(PLOTS / "strategy_family_heatmap.png", dpi=300)
plt.close()


# ---------------------------------------------------------
# Figure 6: Initial Strategy Pools
# ---------------------------------------------------------


strategies = pd.read_csv(
    RESULTS / "strategies.csv",
    header=None,
    names=[
        "run_id",
        "seed",
        "round",
        "agent",
        "strategy",
        "candidate_bid",
        "counter_payoff",
        "sum",
        "n"
    ]
)

# strategies = strategies[
#     (strategies["run_id"] == RUN_ID) &
#     (strategies["seed"] == SEED)
# ]
strategies_all = strategies.copy()

strategies = strategies_all[
    strategies_all["run_id"] == SINGLE_RUN_ID
].copy() 

initial = strategies[strategies["round"] == 1]

all_strategies = [
    "total_return_1",
    "total_return_2",
    "total_return_3",
    "total_return_4",
    "total_return_all_dec3",
    "total_return_all_dec5",

    "unit_return_1",
    "unit_return_2",
    "unit_return_3",
    "unit_return_4",
    "unit_return_all_dec3",
    "unit_return_all_dec5",

    "group_average_0",
    "group_average_1",
    "group_average_2",
    "group_average_3"
]

agent_order = sorted(initial["agent"].unique())

assignment = pd.DataFrame(
    0,
    index=agent_order,
    columns=all_strategies
)

for _, row in initial.iterrows():
    assignment.loc[row["agent"], row["strategy"]] = 1


plt.figure(figsize=(15, 5))

plt.imshow(
    assignment,
    aspect="auto",
    interpolation="nearest"
)

plt.yticks(
    range(len(agent_order)),
    agent_order
)

plt.xticks(
    range(len(all_strategies)),
    all_strategies,
    rotation=60,
    ha="right"
)

plt.xlabel("Strategy")
plt.ylabel("Agent")
plt.title("Initial strategy pool assigned to each agent")

plt.tight_layout()
plt.savefig(
    PLOTS / "initial_strategy_pools.png",
    dpi=300
)

plt.close()


# ---------------------------------------------------------
# Figure 7: Agent 1 strategy score trajectories 
# ---------------------------------------------------------

strategies["avg_score"] = (
    strategies["sum"] / strategies["n"]
)

agent_name = "agent1"

agent_scores = strategies[
    strategies["agent"] == agent_name
]

plt.figure(figsize=(10, 5))

for strategy, data in agent_scores.groupby("strategy"):
    data = data.sort_values("round")

    plt.plot(
        data["round"],
        data["avg_score"],
        label=strategy
    )

plt.xlabel("Round")
plt.ylabel("Average counterfactual return")
plt.title(f"Strategy scores over time — {agent_name}")
plt.legend()
plt.tight_layout()

plt.savefig(
    PLOTS / "agent1_strategy_scores.png",
    dpi=300
)

plt.close()


# ---------------------------------------------------------
# Figure 8: Agent 1 counterfactual payoff 
# ---------------------------------------------------------

agent_name = "agent1"

agent_scores = strategies[
    strategies["agent"] == agent_name
]

plt.figure(figsize=(10, 5))

for strategy, data in agent_scores.groupby("strategy"):
    data = data.sort_values("round")

    plt.plot(
        data["round"],
        data["counter_payoff"],
        label=strategy
    )

plt.xlabel("Round")
plt.ylabel("Counterfactual return")
plt.title(f"Per-round strategy returns — {agent_name}")
plt.legend()
plt.tight_layout()

plt.savefig(
    PLOTS / "agent1_strategy_round_returns.png",
    dpi=300
)

plt.close()

# ---------------------------------------------------------
# Investment and performance together
# ---------------------------------------------------------

fig, (ax1, ax2) = plt.subplots(
    2,
    1,
    figsize=(11, 7),
    sharex=True
)

# Group investment
ax1.plot(
    rounds["round"],
    rounds["total_bid"]
)

ax1.axhline(
    36,
    linestyle="--",
    label="Social optimum (36)"
)

ax1.axhline(
    64,
    linestyle=":",
    label="Nash equilibrium (64)"
)

ax1.set_ylabel("Total Market 2 investment")
ax1.set_title("CPR investment and group performance")
ax1.legend()

# Group performance
ax2.plot(
    rounds["round"],
    rounds["rent_pct"]
)

ax2.axhline(
    100,
    linestyle="--",
    label="Social optimum"
)

ax2.set_xlabel("Round")
ax2.set_ylabel("Group rent (% optimum)")
ax2.legend()

plt.tight_layout()

plt.savefig(
    PLOTS / "investment_vs_performance.png",
    dpi=300
)

plt.close()

analysis = rounds.sort_values("round").copy()

# What happens to investment NEXT round?
analysis["next_total_bid"] = analysis["total_bid"].shift(-1)

analysis["delta_bid_next"] = (
    analysis["next_total_bid"]
    - analysis["total_bid"]
)

# What happens to performance NEXT round?
analysis["next_rent_pct"] = analysis["rent_pct"].shift(-1)

analysis["delta_rent_next"] = (
    analysis["next_rent_pct"]
    - analysis["rent_pct"]
)

analysis = analysis.dropna()

performance_to_investment = (
    analysis["rent_pct"]
    .corr(analysis["delta_bid_next"])
)

print(
    "Correlation: current performance -> "
    "next-round change in investment:",
    performance_to_investment
)

plt.figure(figsize=(7, 5))

plt.scatter(
    analysis["rent_pct"],
    analysis["delta_bid_next"]
)

plt.axhline(0, linestyle="--")

plt.xlabel("Group rent in current round (% optimum)")
plt.ylabel("Change in Market 2 investment next round")
plt.title("Does high performance induce more CPR investment?")

plt.tight_layout()

plt.savefig(
    PLOTS / "performance_to_next_investment.png",
    dpi=300
)

plt.close()

over = analysis[
    analysis["total_bid"] > 36
].copy()

overinvestment_effect = (
    over["delta_bid_next"]
    .corr(over["delta_rent_next"])
)

print(
    "Correlation: change in investment -> "
    "change in performance when above optimum:",
    overinvestment_effect
)

plt.figure(figsize=(7, 5))

plt.scatter(
    over["delta_bid_next"],
    over["delta_rent_next"]
)

plt.axhline(0, linestyle="--")
plt.axvline(0, linestyle="--")

plt.xlabel("Change in Market 2 investment")
plt.ylabel("Change in group rent (% optimum)")
plt.title("Adjustment dynamics above the social optimum")

plt.tight_layout()

plt.savefig(
    PLOTS / "investment_change_vs_performance_change.png",
    dpi=300
)

plt.close()

early = rounds[rounds["round"] <= 50]
late  = rounds[rounds["round"] > 50]

print("Early investment SD:", early["total_bid"].std())
print("Late investment SD:", late["total_bid"].std())

print("Early performance SD:", early["rent_pct"].std())
print("Late performance SD:", late["rent_pct"].std())

# ---------------------------------------------------------
# 30-run baseline summary
# ---------------------------------------------------------

summaries = []

for (run_id, seed), data in rounds_all.groupby(
    ["run_id", "seed"]
):
    data = data.sort_values("round").copy()

    early = data[data["round"] <= 50]
    late = data[data["round"] > 50]

    # Current performance -> next-round investment change
    analysis = data.copy()

    analysis["next_total_bid"] = (
        analysis["total_bid"].shift(-1)
    )

    analysis["delta_bid_next"] = (
        analysis["next_total_bid"]
        - analysis["total_bid"]
    )

    analysis["next_rent_pct"] = (
        analysis["rent_pct"].shift(-1)
    )

    analysis["delta_rent_next"] = (
        analysis["next_rent_pct"]
        - analysis["rent_pct"]
    )

    analysis = analysis.dropna()

    performance_to_investment = (
        analysis["rent_pct"]
        .corr(analysis["delta_bid_next"])
    )

    over = analysis[
        analysis["total_bid"] > 36
    ]

    if len(over) > 1:
        overinvestment_effect = (
            over["delta_bid_next"]
            .corr(over["delta_rent_next"])
        )
    else:
        overinvestment_effect = float("nan")

    summaries.append({
        "run_id": run_id,
        "seed": seed,

        "mean_rent_pct":
            data["rent_pct"].mean(),

        "mean_total_bid":
            data["total_bid"].mean(),

        "final_total_bid":
            data.iloc[-1]["total_bid"],

        "final_rent_pct":
            data.iloc[-1]["rent_pct"],

        "early_investment_sd":
            early["total_bid"].std(),

        "late_investment_sd":
            late["total_bid"].std(),

        "early_performance_sd":
            early["rent_pct"].std(),

        "late_performance_sd":
            late["rent_pct"].std(),

        "fraction_above_optimum":
            (data["total_bid"] > 36).mean(),

        "performance_to_next_investment_corr":
            performance_to_investment,

        "overinvestment_change_corr":
            overinvestment_effect
    })


summary = pd.DataFrame(summaries)

summary.to_csv(
    RESULTS / "baseline_30_summary.csv",
    index=False
)

# print("\n=== 30-RUN SUMMARY ===")
# print(summary)

switch_rows = []

for (run_id, seed, agent), data in agents_all.groupby(
    ["run_id", "seed", "agent"]
):
    data = data.sort_values("round")

    switches = (
        data["strategy"]
        .ne(data["strategy"].shift())
        .iloc[1:]
        .sum()
    )

    switch_rows.append({
        "run_id": run_id,
        "seed": seed,
        "agent": agent,
        "switches": switches
    })


switches = pd.DataFrame(switch_rows)

switch_summary = (
    switches
    .groupby(["run_id", "seed"])["switches"]
    .sum()
    .reset_index(name="total_strategy_switches")
)

summary = summary.merge(
    switch_summary,
    on=["run_id", "seed"]
)

plt.figure(figsize=(7, 6))

plt.scatter(
    summary["early_investment_sd"],
    summary["late_investment_sd"]
)

limit = max(
    summary["early_investment_sd"].max(),
    summary["late_investment_sd"].max()
)

plt.plot(
    [0, limit],
    [0, limit],
    linestyle="--"
)

plt.xlabel("Investment SD — rounds 1–50")
plt.ylabel("Investment SD — rounds 51–100")
plt.title("Does CPR investment oscillation damp over time?")

plt.tight_layout()

plt.savefig(
    PLOTS / "oscillation_damping_30_runs.png",
    dpi=300
)

plt.close()

plt.figure(figsize=(11, 6))

for run_id, data in rounds_all.groupby("run_id"):
    data = data.sort_values("round")

    plt.plot(
        data["round"],
        data["total_bid"],
        alpha=0.25
    )

mean_by_round = (
    rounds_all
    .groupby("round")["total_bid"]
    .mean()
)

plt.plot(
    mean_by_round.index,
    mean_by_round.values,
    linewidth=3,
    label="Mean across 30 runs"
)

plt.axhline(
    36,
    linestyle="--",
    label="Social optimum (36)"
)

plt.axhline(
    64,
    linestyle=":",
    label="Nash equilibrium (64)"
)

plt.xlabel("Round")
plt.ylabel("Total Market 2 investment")
plt.title("Market 2 investment across 30 baseline runs")
plt.legend()

plt.tight_layout()

plt.savefig(
    PLOTS / "investment_30_runs.png",
    dpi=300
)

plt.close()

plt.figure(figsize=(11, 6))

for run_id, data in rounds_all.groupby("run_id"):
    data = data.sort_values("round")

    plt.plot(
        data["round"],
        data["rent_pct"],
        alpha=0.25
    )

mean_by_round = (
    rounds_all
    .groupby("round")["rent_pct"]
    .mean()
)

plt.plot(
    mean_by_round.index,
    mean_by_round.values,
    linewidth=3,
    label="Mean across 30 runs"
)

plt.axhline(
    100,
    linestyle="--",
    label="Social optimum"
)

plt.xlabel("Round")
plt.ylabel("Group rent (% of optimum)")
plt.title("Group performance across 30 baseline runs")
plt.legend()

plt.tight_layout()

plt.savefig(
    PLOTS / "performance_30_runs.png",
    dpi=300
)

plt.close()