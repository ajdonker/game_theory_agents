"""Analyze STRIPS-controlled CPR simulation results.

Install: pip install pandas matplotlib
Run from any directory:
    python gametheory/analysis/adaptive_analysis.py --run-id 3 --seed 42

Inputs: gametheory/results/adaptive/{rounds,agents,modes,decisions}.csv
Optional: central_choices.csv, coalition_links.csv
Output: gametheory/results/adaptive/plots/run_<id>_seed_<seed>/
        gametheory/results/adaptive/adaptive_summary.csv
"""
from pathlib import Path
import argparse
import warnings

import matplotlib.pyplot as plt
import pandas as pd

BASE = Path(__file__).resolve().parent.parent / "results" / "adaptive"
COLUMNS = {
    "rounds": ["run_id", "seed", "round", "total_bid", "average_bid", "group_rent", "rent_pct"],
    "agents": ["run_id", "seed", "round", "agent", "strategy", "bid", "market1", "market2", "payoff"],
    "modes": ["run_id", "seed", "round", "mode"],
    "decisions": ["run_id", "seed", "round", "current", "proposed", "applied", "age", "streak"],
    "central_choices": ["run_id", "seed", "round", "bid"],
    "coalition_links": ["run_id", "seed", "round", "agent", "peer"],
}
MODES = ["none", "decentralized", "coalition", "centralized"]
MODE_COLORS = {
    "none": "#adb5bd",
    "decentralized": "#58b4a3",
    "coalition": "#b392cf",
    "centralized": "#e6a15c",
}
OPTIMUM = 36.0
BAND = 0.15 * OPTIMUM


def load(name, required=True):
    path = BASE / f"{name}.csv"
    if not path.exists() or path.stat().st_size == 0:
        if not required:
            return pd.DataFrame(columns=COLUMNS[name])
        raise FileNotFoundError(f"Missing {path}. Run the adaptive simulation with CSV logging enabled.")
    data = pd.read_csv(path, header=None, names=COLUMNS[name], skipinitialspace=True)
    for key in ["run_id", "seed", "round"]:
        data[key] = pd.to_numeric(data[key], errors="coerce")
    data = data.dropna(subset=["run_id", "seed", "round"]).copy()
    data[["run_id", "seed", "round"]] = data[["run_id", "seed", "round"]].astype(int)
    for key in ["mode", "current", "proposed", "applied", "agent", "peer", "strategy"]:
        if key in data:
            data[key] = data[key].astype(str).str.strip().str.strip('"').str.strip("'")
    return data


def select(data, run_id, seed):
    return data.loc[(data.run_id == run_id) & (data.seed == seed)].sort_values("round").copy()


def require_unique(data, name):
    if data.duplicated(["run_id", "seed", "round"]).any():
        raise ValueError(f"Duplicate run/seed/round in {name}. Move old CSVs out before rerunning.")


def episodes(modes):
    """Consecutive active-mode episodes, including the final incomplete episode."""
    if modes.empty:
        return pd.DataFrame(columns=["mode", "start_round", "end_round", "duration"])
    frame = modes.sort_values("round").copy()
    frame["episode"] = frame["mode"].ne(frame["mode"].shift()).cumsum()
    out = (frame.groupby("episode", as_index=False)
           .agg(mode=("mode", "first"), start_round=("round", "min"),
                end_round=("round", "max"), duration=("round", "size")))
    return out.drop(columns="episode")


def plot_series(df, eps, column, ylabel, title, output, reference=None):
    fig, ax = plt.subplots(figsize=(13, 5))
    for row in eps.itertuples(index=False):
        ax.axvspan(row.start_round - 0.5, row.end_round + 0.5,
                   color=MODE_COLORS.get(row.mode, "#ddd"), alpha=0.19, linewidth=0)
    ax.plot(df["round"], df[column], color="#1d3557", linewidth=1.3)
    if reference is not None:
        value, label = reference
        ax.axhline(value, color="#a33a3a", linestyle="--", label=label)
        ax.legend(loc="best")
    ax.set(xlabel="Round", ylabel=ylabel, title=title,
           xlim=(df["round"].min() - 0.5, df["round"].max() + 0.5))
    fig.tight_layout()
    fig.savefig(output, dpi=200)
    plt.close(fig)


def summarize_one(rounds, modes, agents):
    merged = rounds.merge(modes[["round", "mode"]], on="round", validate="one_to_one")
    length = len(merged)
    eps = episodes(modes)
    result = {
        "run_id": int(rounds.run_id.iloc[0]), "seed": int(rounds.seed.iloc[0]),
        "rounds": length, "mean_rent_pct": merged.rent_pct.mean(),
        "final_rent_pct": merged.sort_values("round").rent_pct.iloc[-1],
        "mean_total_bid": merged.total_bid.mean(),
        "final_total_bid": merged.sort_values("round").total_bid.iloc[-1],
        "mean_abs_distance_from_36": (merged.total_bid - OPTIMUM).abs().mean(),
        "fraction_within_15pct_band": ((merged.total_bid - OPTIMUM).abs() <= BAND).mean(),
        "fraction_above_optimum": (merged.total_bid > OPTIMUM).mean(),
        "mode_switches": max(0, len(eps) - 1),
    }
    for m in MODES:
        subset = merged[merged["mode"] == m]
        result[f"rounds_{m}"] = len(subset)
        result[f"share_{m}"] = len(subset) / length if length else float("nan")
        result[f"mean_rent_{m}"] = subset.rent_pct.mean() if len(subset) else float("nan")
    result["mean_individual_bid_sd"] = agents.groupby("round").bid.std(ddof=0).mean()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", type=int)
    parser.add_argument("--seed", type=int)
    args = parser.parse_args()

    all_rounds = load("rounds")
    all_modes = load("modes")
    all_agents = load("agents")
    decisions_all = load("decisions", required=False)
    choices_all = load("central_choices", required=False)
    links_all = load("coalition_links", required=False)
    for data, name in [(all_rounds, "rounds"), (all_modes, "modes"), (decisions_all, "decisions")]:
        require_unique(data, name)

    # Summaries use all complete (run_id, seed) combinations.
    keys = all_rounds[["run_id", "seed"]].drop_duplicates().sort_values(["run_id", "seed"])
    summaries = []
    for k in keys.itertuples(index=False):
        r = select(all_rounds, k.run_id, k.seed)
        m = select(all_modes, k.run_id, k.seed)
        a = select(all_agents, k.run_id, k.seed)
        if len(r) != len(m) or set(r["round"]) != set(m["round"]):
            warnings.warn(f"Skipping summary for run={k.run_id}, seed={k.seed}: missing modes")
            continue
        summaries.append(summarize_one(r, m, a))
    if summaries:
        pd.DataFrame(summaries).to_csv(BASE / "adaptive_summary.csv", index=False)

    # Across-run plots answer: does the planner overuse a single mode?
    aggregate_dir = BASE / "plots" / "all_runs"
    aggregate_dir.mkdir(parents=True, exist_ok=True)
    shares = (all_modes.groupby("round")["mode"].value_counts(normalize=True)
              .unstack(fill_value=0).reindex(columns=MODES, fill_value=0).sort_index())
    if not shares.empty:
        fig, ax = plt.subplots(figsize=(12, 5))
        ax.stackplot(shares.index, *[shares[m] for m in MODES],
                     labels=MODES, colors=[MODE_COLORS[m] for m in MODES], alpha=0.85)
        ax.set(xlabel="Round", ylabel="Share of recorded runs", ylim=(0, 1),
               title="Active intervention modes across runs")
        ax.legend(loc="upper right")
        fig.tight_layout()
        fig.savefig(aggregate_dir / "mode_share_by_round.png", dpi=200)
        plt.close(fig)
        shares.to_csv(aggregate_dir / "mode_share_by_round.csv")
    for name, field, target, baseline in [
        ("rent", "rent_pct", 100.0, "Social optimum = 100%"),
        ("investment", "total_bid", OPTIMUM, "Social optimum = 36"),
    ]:
        traces = all_rounds.groupby("round")[field].agg(["mean", "std"]).sort_index()
        fig, ax = plt.subplots(figsize=(12, 5))
        ax.plot(traces.index, traces["mean"], label="Mean across recorded runs")
        if traces["std"].notna().any():
            low = traces["mean"] - traces["std"].fillna(0)
            high = traces["mean"] + traces["std"].fillna(0)
            ax.fill_between(traces.index, low, high, alpha=0.2, label="±1 SD")
        ax.axhline(target, linestyle="--", label=baseline)
        ax.set(xlabel="Round", ylabel=("Rent (% optimum)" if name == "rent" else "Total Market 2 bid"),
               title=f"Adaptive {name} across recorded runs")
        ax.legend()
        fig.tight_layout()
        fig.savefig(aggregate_dir / f"{name}_across_runs.png", dpi=200)
        plt.close(fig)

    # Display the requested run, or the first existing (run_id, seed).
    filtered = keys
    if args.run_id is not None:
        filtered = filtered[filtered.run_id == args.run_id]
    if args.seed is not None:
        filtered = filtered[filtered.seed == args.seed]
    if filtered.empty:
        raise ValueError("No matching run. Available (run_id, seed): " + str(keys.values.tolist()))
    run_id, seed = map(int, filtered.iloc[0][["run_id", "seed"]])
    r = select(all_rounds, run_id, seed)
    m = select(all_modes, run_id, seed)
    a = select(all_agents, run_id, seed)
    d = select(decisions_all, run_id, seed)
    c = select(choices_all, run_id, seed)
    links = select(links_all, run_id, seed)
    if len(r) != len(m) or set(r["round"]) != set(m["round"]):
        raise ValueError("Round and mode logs do not match; clean and rerun the simulation.")
    if a.groupby("round").agent.nunique().reindex(r["round"]).ne(8).any():
        warnings.warn("Not every recorded round has eight distinct agents. Check simulation completion.")

    out = BASE / "plots" / f"run_{run_id}_seed_{seed}"
    out.mkdir(parents=True, exist_ok=True)
    ep = episodes(m)
    ep.to_csv(out / "intervention_episodes.csv", index=False)
    merged = r.merge(m[["round", "mode"]], on="round", validate="one_to_one")
    merged.to_csv(out / "rounds_with_modes.csv", index=False)

    print(f"\nADAPTIVE RUN {run_id}, SEED {seed}: {len(r)} rounds")
    print("\nTime in each intervention mode:")
    counts = m["mode"].value_counts().reindex(MODES, fill_value=0)
    print(pd.DataFrame({"rounds": counts, "share_pct": (counts / len(m) * 100).round(1)}).to_string())
    print(f"\nMode switches: {len(ep) - 1}")
    print("\nMode episodes:")
    print(ep.to_string(index=False))
    if (counts[["decentralized", "coalition"]] == 0).any():
        print("\nIMPORTANT: At least one of decentralized/coalition never occurred in this run.")

    # Mode timeline
    fig, ax = plt.subplots(figsize=(13, 3.3))
    codes = {mode: i for i, mode in enumerate(MODES)}
    ax.step(m["round"], m["mode"].map(codes), where="mid", linewidth=2)
    ax.set(yticks=list(codes.values()), yticklabels=list(codes),
           xlabel="Round", title="Intervention selected by STRIPS (mode active at round start)")
    fig.tight_layout()
    fig.savefig(out / "mode_timeline.png", dpi=200)
    plt.close(fig)

    plot_series(r, ep, "total_bid", "Group Market 2 investment", "Investment by active intervention",
                out / "investment_by_mode.png", (OPTIMUM, "Social optimum = 36"))
    plot_series(r, ep, "rent_pct", "Group rent (% of optimum)", "Performance by active intervention",
                out / "rent_by_mode.png", (100, "Maximum group rent = 100%"))

    # Descriptive by-mode performance, not a causal estimate.
    grouped = (merged.groupby("mode", as_index=False)
               .agg(rounds=("round", "count"), mean_rent_pct=("rent_pct", "mean"),
                    mean_total_bid=("total_bid", "mean"),
                    rent_sd=("rent_pct", "std")))
    grouped["mean_abs_distance_from_36"] = grouped["mode"].map(
        merged.assign(error=(merged.total_bid - OPTIMUM).abs()).groupby("mode").error.mean()
    )
    grouped.to_csv(out / "performance_by_mode.csv", index=False)
    print("\nPerformance while each mode was active (descriptive only):")
    print(grouped.round(2).to_string(index=False))

    fig, ax = plt.subplots(figsize=(8, 4))
    ax.bar(counts.index, counts.values, color=[MODE_COLORS[x] for x in counts.index])
    ax.set(xlabel="Intervention", ylabel="Rounds", title="Intervention occupancy")
    fig.tight_layout()
    fig.savefig(out / "mode_occupancy.png", dpi=200)
    plt.close(fig)

    bid_sd = a.groupby("round").bid.std(ddof=0).reset_index(name="bid_sd")
    mode_sd = m.merge(bid_sd, on="round", how="left")
    plot_series(mode_sd, ep, "bid_sd", "SD of 8 agent bids",
                "Bid coordination by active intervention", out / "bid_dispersion_by_mode.png")

    # Proposed vs applied intervention; each decision at round R governs R+1.
    if not d.empty:
        d = d.sort_values("round").copy()
        d["next_mode"] = d["applied"].where(d["applied"] != "keep", d["current"])
        d["next_round"] = d["round"] + 1
        joined = d.merge(m[["round", "mode"]], left_on="next_round", right_on="round", how="inner",
                         suffixes=("_decision", "_actual"))
        mismatches = joined[joined.next_mode != joined["mode"]]
        print(f"\nLogged STRIPS decisions: {len(d)}; expected next-mode mismatches: {len(mismatches)}")
        if not mismatches.empty:
            warnings.warn("Applied decisions do not match the subsequent mode; inspect decisions.csv")
        d.to_csv(out / "decision_audit.csv", index=False)
        changes = d[d.proposed != d.applied]
        print(f"Decisions vetoed or altered by duration/streak rules: {len(changes)}")
        print("Proposed intervention counts:")
        print(d.proposed.value_counts().to_string())

    # Check that central chosen bid is followed in the NEXT round.
    if not c.empty:
        next_agent = a.copy()
        checks = []
        for row in c.itertuples(index=False):
            nxt = next_agent[next_agent["round"] == row.round + 1]
            next_mode = m.loc[m["round"] == row.round + 1, "mode"]
            if len(nxt) == 8 and len(next_mode) and next_mode.iloc[0] == "centralized":
                checks.append({"decision_round": row.round, "chosen_bid": row.bid,
                               "agents_match": int((abs(nxt.bid - row.bid) < 1e-8).sum())})
        if checks:
            audit = pd.DataFrame(checks)
            audit.to_csv(out / "centralized_adoption.csv", index=False)
            print(f"\nCentralized adoption: {(audit.agents_match == 8).sum()}/{len(audit)} checked rounds with all 8 matching")
        else:
            print("\nNo eligible subsequent centralized rounds for central-adoption audit.")

    if not links.empty:
        # Each mutual coalition link may be logged twice (A->B and B->A).
        link = links.copy()
        link["pair"] = link.apply(lambda z: "-".join(sorted([z.agent, z.peer])), axis=1)
        unique = link.drop_duplicates(["round", "pair"])
        ccount = (unique.groupby("round").size().rename("coalition_links")
                  .reindex(r["round"], fill_value=0).reset_index())
        plot_series(ccount, ep, "coalition_links", "Mutual coalition links",
                    "Formed coalition links over time", out / "coalition_links_by_mode.png")
        print(f"Coalition links logged: {len(unique)} distinct round-pairs")

    print(f"\nPlots and per-run reports written to: {out}")
    print(f"All-run descriptive summary: {BASE / 'adaptive_summary.csv'}")


if __name__ == "__main__":
    main()
