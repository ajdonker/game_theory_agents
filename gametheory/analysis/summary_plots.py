"""
Create scenario-level comparison plots and an adaptive mode timeline.

Install:
    pip install pandas matplotlib

Run:
    python gametheory/analysis/summary_plots.py
    python gametheory/analysis/summary_plots.py --run-id 1 --seed 42
"""

from pathlib import Path
import argparse
import matplotlib.pyplot as plt
import pandas as pd

RESULTS = Path(__file__).resolve().parent.parent / "results"
SCENARIOS = ["adaptive", "centralized", "decentralized", "coalition", "no_comm"]
OPTIMUM = 36.0


def read_rounds(scenario):
    path = RESULTS / scenario / "rounds.csv"
    if not path.exists():
        print(f"Missing: {path}")
        return None
    df = pd.read_csv(
        path,
        header=None,
        names=["run_id", "seed", "round", "total_bid", "avg", "rent", "rent_pct"],
        skipinitialspace=True
    )
    for col in ["run_id", "seed", "round", "total_bid", "avg", "rent", "rent_pct"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df = df.dropna(subset=["run_id", "seed", "round", "total_bid", "rent_pct"])
    df[["run_id", "seed", "round"]] = df[["run_id", "seed", "round"]].astype(int)
    return df


def read_adaptive_decisions():
    path = RESULTS / "adaptive" / "decisions.csv"
    if not path.exists():
        print(f"Missing: {path}")
        return None
    df = pd.read_csv(
        path,
        header=None,
        names=[
            "run_id", "seed", "round",
            "current_mode", "proposed_mode", "selected_mode",
            "mode_age", "optimal_count"
        ],
        skipinitialspace=True
    )
    for col in ["run_id", "seed", "round", "mode_age", "optimal_count"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df = df.dropna(subset=["run_id", "seed", "round"])
    df[["run_id", "seed", "round"]] = df[["run_id", "seed", "round"]].astype(int)
    return df


def ensure_dir(path):
    path.mkdir(parents=True, exist_ok=True)
    return path


def plot_mean_total_bid_bar(rounds_map, out_dir):
    rows = []
    for scenario, df in rounds_map.items():
        if df is None or df.empty:
            continue
        rows.append({
            "scenario": scenario,
            "mean_total_bid": df["total_bid"].mean()
        })
    if not rows:
        return

    summary = pd.DataFrame(rows).sort_values("mean_total_bid")
    summary.to_csv(out_dir / "scenario_mean_total_bid.csv", index=False)

    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.bar(summary["scenario"], summary["mean_total_bid"])
    ax.axhline(OPTIMUM, linestyle="--", color="black", linewidth=1)
    ax.set_ylabel("Mean total group investment")
    ax.set_title("Mean collective investment by scenario")
    fig.tight_layout()
    fig.savefig(out_dir / "scenario_mean_total_bid.png", dpi=200)
    plt.close(fig)


def plot_mean_total_bid_over_time(rounds_map, out_dir):
    fig, ax = plt.subplots(figsize=(10, 5))

    for scenario, df in rounds_map.items():
        if df is None or df.empty:
            continue
        by_round = (
            df.groupby("round", as_index=False)["total_bid"]
            .mean()
            .sort_values("round")
        )
        ax.plot(by_round["round"], by_round["total_bid"], label=scenario)

    ax.axhline(OPTIMUM, linestyle="--", color="black", linewidth=1)
    ax.set_xlabel("Round")
    ax.set_ylabel("Mean total group investment")
    ax.set_title("Mean collective investment over time")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out_dir / "scenario_total_bid_over_time.png", dpi=200)
    plt.close(fig)


def plot_mean_rent_over_time(rounds_map, out_dir):
    fig, ax = plt.subplots(figsize=(10, 5))

    for scenario, df in rounds_map.items():
        if df is None or df.empty:
            continue
        by_round = (
            df.groupby("round", as_index=False)["rent_pct"]
            .mean()
            .sort_values("round")
        )
        ax.plot(by_round["round"], by_round["rent_pct"], label=scenario)

    ax.set_xlabel("Round")
    ax.set_ylabel("Mean rent (% of optimum)")
    ax.set_title("Mean collective rent over time")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out_dir / "scenario_rent_over_time.png", dpi=200)
    plt.close(fig)


def reconstruct_mode_timeline(decisions, run_id, seed, max_round=None):
    d = decisions[(decisions.run_id == run_id) & (decisions.seed == seed)].copy()
    if d.empty:
        raise ValueError(f"No adaptive decisions for run_id={run_id}, seed={seed}")

    d = d.sort_values("round")

    if max_round is None:
        max_round = int(d["round"].max())

    rounds = list(range(1, max_round + 1))
    active_mode = "none"
    current_by_round = {}
    next_mode_by_round = {}

    for _, row in d.iterrows():
        r = int(row["round"])
        current_by_round[r] = str(row["current_mode"]).strip()
        next_mode_by_round[r] = str(row["selected_mode"]).strip()

    timeline = []
    for r in rounds:
        # mode active during round r
        mode_this_round = current_by_round.get(r, active_mode)
        timeline.append({"round": r, "mode": mode_this_round})

        # mode chosen at end of round r becomes active in round r+1
        if r in next_mode_by_round:
            active_mode = next_mode_by_round[r]

    return pd.DataFrame(timeline)


def plot_adaptive_timeline(decisions, run_id, seed, out_dir, max_round=None):
    timeline = reconstruct_mode_timeline(decisions, run_id, seed, max_round=max_round)

    mode_order = ["none", "decentralized", "centralized", "coalition"]
    mode_to_y = {m: i for i, m in enumerate(mode_order)}
    timeline["y"] = timeline["mode"].map(mode_to_y)

    fig, ax = plt.subplots(figsize=(11, 3.8))
    ax.step(timeline["round"], timeline["y"], where="post")
    ax.set_yticks(range(len(mode_order)))
    ax.set_yticklabels(mode_order)
    ax.set_xlabel("Round")
    ax.set_ylabel("Active intervention")
    ax.set_title(f"Adaptive intervention timeline (run_id={run_id}, seed={seed})")
    fig.tight_layout()
    fig.savefig(out_dir / f"adaptive_timeline_run{run_id}_seed{seed}.png", dpi=200)
    plt.close(fig)

    timeline.to_csv(out_dir / f"adaptive_timeline_run{run_id}_seed{seed}.csv", index=False)


def plot_adaptive_mode_share(decisions, out_dir):
    if decisions is None or decisions.empty:
        return

    # reconstruct a timeline for every adaptive run/seed pair
    pairs = (
        decisions[["run_id", "seed"]]
        .drop_duplicates()
        .sort_values(["run_id", "seed"])
        .itertuples(index=False, name=None)
    )

    all_timeline = []
    for run_id, seed in pairs:
        tl = reconstruct_mode_timeline(decisions, run_id, seed)
        tl["run_id"] = run_id
        tl["seed"] = seed
        all_timeline.append(tl)

    if not all_timeline:
        return

    timeline = pd.concat(all_timeline, ignore_index=True)
    share = (
        timeline["mode"]
        .value_counts(normalize=True)
        .rename_axis("mode")
        .reset_index(name="share")
    )
    share["share_pct"] = 100 * share["share"]
    share.to_csv(out_dir / "adaptive_mode_share.csv", index=False)

    fig, ax = plt.subplots(figsize=(7, 4))
    ax.bar(share["mode"], share["share_pct"])
    ax.set_ylabel("Share of adaptive rounds (%)")
    ax.set_title("Distribution of adaptive intervention modes")
    fig.tight_layout()
    fig.savefig(out_dir / "adaptive_mode_share.png", dpi=200)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", type=int, default=1,
                        help="Adaptive run_id to use for the timeline plot")
    parser.add_argument("--seed", type=int, default=42,
                        help="Adaptive seed to use for the timeline plot")
    parser.add_argument("--max-round", type=int, default=None,
                        help="Optional maximum round for the adaptive timeline")
    args = parser.parse_args()

    out_dir = ensure_dir(RESULTS / "summary_plots")

    rounds_map = {scenario: read_rounds(scenario) for scenario in SCENARIOS}

    plot_mean_total_bid_bar(rounds_map, out_dir)
    plot_mean_total_bid_over_time(rounds_map, out_dir)
    plot_mean_rent_over_time(rounds_map, out_dir)

    decisions = read_adaptive_decisions()
    if decisions is not None and not decisions.empty:
        plot_adaptive_timeline(
            decisions,
            run_id=args.run_id,
            seed=args.seed,
            out_dir=out_dir,
            max_round=args.max_round
        )
        plot_adaptive_mode_share(decisions, out_dir)

    print(f"Saved plots to: {out_dir}")


if __name__ == "__main__":
    main()