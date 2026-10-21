import pandas as pd

root = "gametheory/results/centralized/"

rounds = pd.read_csv(
    root + "rounds.csv", header=None,
    names=["run_id", "seed", "round", "total", "average", "rent", "rent_pct"]
)

choices = pd.read_csv(
    root + "central_strategy_choices.csv", header=None,
    names=["run_id", "seed", "decision_round", "strategy", "predicted_total", "predicted_rent"]
)

# Compare performance by round within each communication cycle.
after = rounds[rounds["round"] >= 6].copy()
after["cycle_round"] = (after["round"] - 6) % 5 + 1

print(after.groupby("cycle_round")["rent_pct"].agg(["mean", "std", "count"]).round(2))

# Did the selected strategy produce the predicted total in the following round?
choices["round"] = choices["decision_round"] + 1
check = choices.merge(rounds, on=["run_id", "seed", "round"])

print("Predicted vs actual investment mismatches:",
      (check["predicted_total"] != check["total"]).sum())

print("Total round observations:", len(rounds))

print(
    rounds.groupby("run_id")["round"]
    .nunique()
    .describe()
)

print(
    after["cycle_round"]
    .value_counts()
    .reindex(range(1, 6), fill_value=0)
    .sort_index()
)

print(
    "Missing rounds in run 1:",
    sorted(
        set(range(1, 101))
        - set(rounds.loc[rounds["run_id"] == 1, "round"])
    )
)
agents = pd.read_csv(
    root + "agents.csv",
    header=None,
    names=[
        "run_id", "seed", "round", "agent",
        "strategy", "bid", "market1", "market2", "payoff"
    ]
)

choices = pd.read_csv(
    root + "central_strategy_choices.csv",
    header=None,
    names=[
        "run_id", "seed", "decision_round",
        "central_strategy", "predicted_total", "predicted_rent"
    ]
)

agents = agents[agents["round"] >= 6].copy()

agents["decision_round"] = (
    (agents["round"] - 1) // 5
) * 5

agents["cycle_pos"] = (
    (agents["round"] - 6) % 5
) + 1

data = agents.merge(
    choices,
    on=["run_id", "seed", "decision_round"],
    validate="many_to_one"
)

data["follows_central"] = (
    data["strategy"] == data["central_strategy"]
)

print(
    data.groupby("cycle_pos")
    .agg(
        share_following=("follows_central", "mean"),
        mean_individual_bid=("bid", "mean")
    )
    .round(3)
)

print(
    data.groupby(["cycle_pos", "follows_central"])
    .agg(
        mean_bid=("bid", "mean"),
        observations=("bid", "size")
    )
    .round(2)
)