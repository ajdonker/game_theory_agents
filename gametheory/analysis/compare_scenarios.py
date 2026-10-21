"""Compare adaptive STRIPS run(s) with fixed-intervention baselines.

Install: pip install pandas matplotlib
Run: python gametheory/analysis/compare_scenarios.py
     python gametheory/analysis/compare_scenarios.py --rounds 100

Matches on SEED, irrespective of run_id, and uses the SAME rounds in each
adaptive/baseline pair. Multiple runs with the same seed within a scenario
are an error; move stale CSVs before rerunning.
"""
from pathlib import Path
import argparse
import matplotlib.pyplot as plt
import pandas as pd

RESULTS = Path(__file__).resolve().parent.parent / "results"
SCENARIOS = ["no_comm", "centralized", "decentralized", "coalition"]
OPTIMUM = 36.0


def read_rounds(scenario):
    path = RESULTS / scenario / "rounds.csv"
    if not path.exists():
        return None
    df = pd.read_csv(path, header=None,
                     names=["run_id", "seed", "round", "total_bid", "avg", "rent", "rent_pct"],
                     skipinitialspace=True)
    for field in ["run_id", "seed", "round", "total_bid", "rent_pct"]:
        df[field] = pd.to_numeric(df[field], errors="coerce")
    df = df.dropna(subset=["run_id", "seed", "round", "total_bid", "rent_pct"])
    df[["run_id", "seed", "round"]] = df[["run_id", "seed", "round"]].astype(int)
    if df.duplicated(["seed", "round"]).any():
        raise ValueError(f"Repeated seed/round observations in {path}; remove old run output first.")
    return df


def metrics(frame):
    return {
        "mean_rent_pct": frame.rent_pct.mean(),
        "mean_distance_from_optimum": (frame.total_bid - OPTIMUM).abs().mean(),
        "fraction_within_optimal_band": ((frame.total_bid - OPTIMUM).abs() <= 5.4).mean(),
        "rent_sd": frame.rent_pct.std(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rounds", type=int, default=None,
                        help="Compare at most this many earliest common rounds (e.g. 100)")
    args = parser.parse_args()
    adaptive = read_rounds("adaptive")
    if adaptive is None:
        raise FileNotFoundError("No results/adaptive/rounds.csv. Run the STRIPS scenario first.")
    out = RESULTS / "adaptive" / "comparison"
    out.mkdir(parents=True, exist_ok=True)
    rows = []
    for scenario in SCENARIOS:
        base = read_rounds(scenario)
        if base is None:
            print(f"Skipping {scenario}: results/{scenario}/rounds.csv missing")
            continue
        seeds = sorted(set(adaptive.seed) & set(base.seed))
        if not seeds:
            print(f"Skipping {scenario}: no shared seeds with adaptive results")
            continue
        for seed in seeds:
            a = adaptive[adaptive.seed == seed].copy()
            b = base[base.seed == seed].copy()
            # Include only rounds recorded in BOTH scenarios.
            merged = a.merge(b, on=["seed", "round"], suffixes=("_adaptive", "_baseline"),
                             validate="one_to_one")
            if args.rounds is not None:
                merged = merged.loc[merged["round"].between(1, args.rounds)].copy()
                if set(merged["round"]) != set(range(1, args.rounds + 1)):
                    print(f"Skipping scenario={scenario}, seed={seed}: "
                          f"not all rounds 1..{args.rounds} are present in both datasets")
                    continue
            if merged.empty:
                continue
            if args.rounds is None and len(merged) < min(len(a), len(b)):
                print(f"Warning: scenario={scenario}, seed={seed}: missing common rounds")
            ra = pd.DataFrame({"total_bid": merged.total_bid_adaptive,
                               "rent_pct": merged.rent_pct_adaptive})
            rb = pd.DataFrame({"total_bid": merged.total_bid_baseline,
                               "rent_pct": merged.rent_pct_baseline})
            am, bm = metrics(ra), metrics(rb)
            row = {"baseline": scenario, "seed": seed, "rounds_compared": len(merged),
                   "last_compared_round": int(merged["round"].max())}
            for key in am:
                row[f"adaptive_{key}"] = am[key]
                row[f"baseline_{key}"] = bm[key]
                row[f"delta_{key}"] = am[key] - bm[key]
            rows.append(row)
    if not rows:
        raise SystemExit("No matched adaptive-vs-baseline seed observations. Run fixed baselines with the same seeds.")
    per_run = pd.DataFrame(rows)
    per_run.to_csv(out / "paired_runs.csv", index=False)

    summary = (per_run.groupby("baseline", as_index=False)
               .agg(matched_seeds=("seed", "nunique"),
                    mean_compared_rounds=("rounds_compared", "mean"),
                    delta_mean_rent_pp=("delta_mean_rent_pct", "mean"),
                    delta_mean_distance=("delta_mean_distance_from_optimum", "mean"),
                    delta_fraction_optimal=("delta_fraction_within_optimal_band", "mean"),
                    rent_win_fraction=("delta_mean_rent_pct", lambda s: (s > 0).mean()),
                    distance_win_fraction=("delta_mean_distance_from_optimum", lambda s: (s < 0).mean())))
    summary.to_csv(out / "paired_summary.csv", index=False)
    print("\nAdaptive minus fixed baseline, paired by seed and identical rounds:")
    print(summary.round(3).to_string(index=False))
    print("Positive rent delta is better; NEGATIVE distance delta is better.")
    if summary.matched_seeds.min() < 10:
        print("CAUTION: fewer than 10 paired seeds for at least one baseline; treat as exploratory.")

    fig, ax = plt.subplots(figsize=(9, 4.5))
    ax.bar(summary.baseline, summary.delta_mean_rent_pp)
    ax.axhline(0, linestyle="--", color="black", linewidth=1)
    ax.set(ylabel="Mean difference in rent (% points)",
           title="Adaptive minus fixed baselines (matched seeds/rounds)")
    fig.tight_layout()
    fig.savefig(out / "adaptive_rent_improvement.png", dpi=200)
    plt.close(fig)
    fig, ax = plt.subplots(figsize=(9, 4.5))
    ax.bar(summary.baseline, summary.delta_mean_distance)
    ax.axhline(0, linestyle="--", color="black", linewidth=1)
    ax.set(ylabel="Difference in mean absolute distance from 36",
           title="Adaptive vs fixed baselines (negative is better)")
    fig.tight_layout()
    fig.savefig(out / "adaptive_distance_improvement.png", dpi=200)
    print(f"Reports and figures: {out}")


if __name__ == "__main__":
    main()
