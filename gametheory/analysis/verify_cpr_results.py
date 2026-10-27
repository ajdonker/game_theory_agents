#!/usr/bin/env python3
"""Validate multi-run CPR simulations and compare scenarios with paired statistics.

Expected (headerless OR headed) files:
  results/<scenario>/rounds.csv
    run_id, seed, round, total, average, group_rent, rent_pct
  results/adaptive/modes.csv
    run_id, seed, round, mode
  results/adaptive/decisions.csv
    run_id, seed, round, current, proposed, applied, mode_age, optimal_count

Usage (from repository root):
    python gametheory/analysis/verify_cpr_results.py \\
        --root gametheory/results --runs 30 --rounds 300

Requires: pandas, numpy, scipy.
"""

import argparse
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

ROUND_COLS = ["run_id", "seed", "round", "total", "average", "group_rent", "rent_pct"]
MODE_COLS = ["run_id", "seed", "round", "mode"]
DECISION_COLS = ["run_id", "seed", "round", "current", "proposed", "applied", "mode_age", "optimal_count"]
KEY = ["run_id", "seed", "round"]
PAIR_KEY = ["run_id", "seed"]
DEFAULT_SCENARIOS = ("adaptive", "centralized", "decentralized", "coalition", "no_comm")


def read_csv(path: Path, columns: list[str]) -> pd.DataFrame:
    """Handle Jason results.append (no header) and conventional CSV headers."""
    raw = pd.read_csv(path, header=None, skip_blank_lines=True, dtype=str)
    if raw.shape[1] != len(columns):
        raise ValueError(f"{path}: expected {len(columns)} columns, got {raw.shape[1]}")
    first = str(raw.iloc[0, 0]).strip().lower().lstrip("\ufeff")
    if first in {"run_id", "runid"}:
        raw = raw.iloc[1:].reset_index(drop=True)
    raw.columns = columns
    for column in PAIR_KEY + ["round"]:
        raw[column] = pd.to_numeric(raw[column], errors="raise").astype("int64")
    return raw


def validate_rounds(name: str, df: pd.DataFrame, runs: int, rounds: int) -> list[str]:
    problems = []
    duplicated = int(df.duplicated(KEY).sum())
    n_groups = df.groupby(PAIR_KEY).ngroups
    print(f"  rows={len(df):,}  runs={n_groups}  duplicate run/seed/round={duplicated}")
    if duplicated:
        problems.append(f"{duplicated} duplicate round records")
    if n_groups != runs:
        problems.append(f"expected {runs} runs, got {n_groups}")
    if len(df) != runs * rounds:
        problems.append(f"expected {runs * rounds} rows, got {len(df)}")

    expected = set(range(1, rounds + 1))
    for (rid, seed), group in df.groupby(PAIR_KEY):
        observed = set(group["round"])
        if observed != expected or len(group) != rounds:
            missing = sorted(expected - observed)
            extra = sorted(observed - expected)
            problems.append(
                f"run_id={rid}, seed={seed}: rows={len(group)}, "
                f"missing rounds={missing[:8]}, unexpected rounds={extra[:8]}"
            )

    seeds_per_id = df[PAIR_KEY].drop_duplicates()
    if seeds_per_id["seed"].nunique() != runs:
        problems.append(
            f"only {seeds_per_id['seed'].nunique()} unique seeds across {n_groups} runs "
            "(independence/pairing risk)"
        )
    if seeds_per_id["run_id"].nunique() != runs:
        problems.append("run_id is repeated across multiple seeds")

    for col in ("total", "average", "group_rent", "rent_pct"):
        if not np.isfinite(df[col]).all():
            problems.append(f"{col} contains NaN/inf")

    # Cross-check the economic model: 8 agents; return 23T - .25T²;
    # 5T opportunity cost; optimum T=36; maximum group rent=324.
    errors = {
        "average == total/8": df["average"] - df["total"] / 8,
        "group_rent == 18*T - 0.25*T^2": (
            df["group_rent"] - (18 * df["total"] - 0.25 * df["total"] ** 2)
        ),
        "rent_pct == 100*group_rent/324": (
            df["rent_pct"] - 100 * df["group_rent"] / 324
        ),
    }
    for desc, err in errors.items():
        if not np.isfinite(err).all() or (err.abs() > 0.02).any():
            problems.append(f"economic consistency check failed: {desc}")

    if (df["total"] < 0).any() or (df["total"] > 80).any():
        problems.append("total bid outside [0,80]")

    if problems:
        for issue in problems[:10]:
            print(f"  FAIL: {issue}")
        if len(problems) > 10:
            print(f"  ... {len(problems) - 10} additional issues")
    else:
        print("  PASS: complete, unique and economically consistent")
    return problems


def per_run_metrics(name: str, df: pd.DataFrame) -> pd.DataFrame:
    tmp = df.copy()
    tmp["abs_distance_total"] = (tmp["total"] - 36).abs()
    tmp["abs_distance_per_agent"] = (tmp["average"] - 4.5).abs()
    out = (
        tmp.groupby(PAIR_KEY, as_index=False)
        .agg(
            mean_rent_pct=("rent_pct", "mean"),
            mean_abs_distance_total=("abs_distance_total", "mean"),
            mean_abs_distance_per_agent=("abs_distance_per_agent", "mean"),
            mean_total_investment=("total", "mean"),
        )
    )
    out.insert(0, "scenario", name)
    return out


def paired_summary(deltas: np.ndarray) -> dict:
    """Each paired observation is the difference in per-run averages."""
    n = len(deltas)
    mean = float(np.mean(deltas))
    sd = float(np.std(deltas, ddof=1)) if n > 1 else float("nan")
    if n > 1:
        sem = sd / np.sqrt(n)
        tcrit = stats.t.ppf(0.975, n - 1)
        low, high = mean - tcrit * sem, mean + tcrit * sem
        pval = 1.0 if sd == 0 and mean == 0 else (
            0.0 if sd == 0 else float(stats.ttest_1samp(deltas, popmean=0).pvalue)
        )
    else:
        low = high = pval = float("nan")
    return {
        "n_pairs": n,
        "mean_improvement": mean,
        "ci95_low": low,
        "ci95_high": high,
        "p_paired_ttest": pval,
        "sd_of_differences": sd,
        "cohen_dz": mean / sd if sd > 0 else float("nan"),
        "improved_runs": int((deltas > 0).sum()),
        "tied_runs": int((deltas == 0).sum()),
        "worse_runs": int((deltas < 0).sum()),
    }


def compare_scenarios(metrics: pd.DataFrame, good_names: list[str]) -> tuple[pd.DataFrame, pd.DataFrame]:
    rows = []
    run_differences = []
    adaptive = metrics[metrics["scenario"] == "adaptive"].drop(columns="scenario")
    adaptive_keys = set(map(tuple, adaptive[PAIR_KEY].to_numpy()))
    print("\n=== PAIRED COMPARISONS (positive = adaptive better) ===")
    for baseline in good_names:
        if baseline == "adaptive":
            continue
        base = metrics[metrics["scenario"] == baseline].drop(columns="scenario")
        base_keys = set(map(tuple, base[PAIR_KEY].to_numpy()))
        if adaptive_keys != base_keys:
            only_a = sorted(adaptive_keys - base_keys)
            only_b = sorted(base_keys - adaptive_keys)
            print(f"  SKIP {baseline}: pairing IDs/seeds differ")
            print(f"    only in adaptive: {only_a[:5]}")
            print(f"    only in {baseline}: {only_b[:5]}")
            continue
        paired = adaptive.merge(base, on=PAIR_KEY, how="inner", suffixes=("_adaptive", "_base"), validate="one_to_one")
        comparisons = (
            ("rent_pct_points", paired["mean_rent_pct_adaptive"] - paired["mean_rent_pct_base"]),
            ("distance_total_units", paired["mean_abs_distance_total_base"] - paired["mean_abs_distance_total_adaptive"]),
            ("distance_per_agent_units", paired["mean_abs_distance_per_agent_base"] - paired["mean_abs_distance_per_agent_adaptive"]),
        )
        individual = paired[PAIR_KEY].copy()
        individual.insert(0, "baseline", baseline)
        for measure, values in comparisons:
            individual["improvement_" + measure] = values
        run_differences.append(individual)
        print(f"\n  Adaptive vs {baseline}: {len(paired)} matched run_id/seed pairs")
        for measure, values in comparisons:
            row = {"baseline": baseline, "measure": measure, **paired_summary(values.to_numpy())}
            rows.append(row)
            print(
                f"    {measure:<25} {row['mean_improvement']:+.3f} "
                f"(95% CI [{row['ci95_low']:.3f}, {row['ci95_high']:.3f}]); "
                f"p={row['p_paired_ttest']:.4g}; "
                f"wins={row['improved_runs']}/{row['n_pairs']}"
            )
    return pd.DataFrame(rows), (pd.concat(run_differences, ignore_index=True) if run_differences else pd.DataFrame())


def audit_modes(adaptive: pd.DataFrame, root: Path) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    path = root / "adaptive" / "modes.csv"
    if not path.exists():
        print("\nWARNING: adaptive/modes.csv not found; cannot audit mode usage or transitions")
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()

    modes = read_csv(path, MODE_COLS)
    modes["mode"] = modes["mode"].str.strip().str.lower().replace({"no_intervention": "none"})
    print("\n=== ADAPTIVE MODE AUDIT ===")
    if modes.duplicated(KEY).any():
        print("  FAIL: duplicate records in modes.csv; skipping transition audit")
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()
    expected = set(map(tuple, adaptive[KEY].to_numpy()))
    actual = set(map(tuple, modes[KEY].to_numpy()))
    if expected != actual:
        print(f"  FAIL: modes.csv keys differ from rounds.csv: missing={len(expected-actual)}, unexpected={len(actual-expected)}")
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()
    if not modes["mode"].isin(["none", "centralized", "decentralized", "coalition"]).all():
        print("  FAIL: unknown mode name in modes.csv")
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()

    usage = (
        modes.groupby(PAIR_KEY + ["mode"]).size().rename("n_rounds").reset_index()
    )
    totals = modes.groupby(PAIR_KEY).size().rename("total_rounds").reset_index()
    usage = usage.merge(totals, on=PAIR_KEY)
    usage["percentage"] = 100 * usage["n_rounds"] / usage["total_rounds"]
    overall = modes["mode"].value_counts(normalize=True) * 100
    print("  Share of all adaptive rounds:")
    for mode, pct in overall.items():
        print(f"    {mode:<14} {pct:6.2f}%")
    for mode in ("centralized", "decentralized", "coalition"):
        active_runs = modes.groupby(PAIR_KEY)["mode"].apply(lambda s: (s == mode).any())
        print(f"    runs using {mode:<13} {int(active_runs.sum())}/{len(active_runs)}")

    joined = adaptive[KEY + ["total", "rent_pct"]].merge(modes, on=KEY, validate="one_to_one")
    joined = joined.sort_values(KEY).reset_index(drop=True)
    joined["next_mode"] = joined.groupby(PAIR_KEY)["mode"].shift(-1)
    change = joined[(joined["next_mode"].notna()) & (joined["mode"] != joined["next_mode"])].copy()
    print(f"  Total actual intervention transitions: {len(change)}")
    for (source, target), num in change.groupby(["mode", "next_mode"]).size().items():
        print(f"    {source} -> {target}: {num}")

    decisions_path = root / "adaptive" / "decisions.csv"
    decisions = pd.DataFrame()
    if decisions_path.exists():
        decisions = read_csv(decisions_path, DECISION_COLS)
        for field in ("current", "proposed", "applied"):
            decisions[field] = decisions[field].str.strip().str.lower().replace({"no_intervention": "none"})
        if decisions.duplicated(KEY).any():
            print("  FAIL: duplicate keys in decisions.csv")
        else:
            checked = joined.merge(decisions, on=KEY, how="left", validate="one_to_one")
            missing = int(checked["current"].isna().sum())
            mode_error = int((checked["current"].notna() & (checked["current"] != checked["mode"])).sum())
            expected_next = np.where(checked["applied"] == "keep", checked["mode"], checked["applied"])
            next_error = int(((checked["next_mode"].notna()) & checked["applied"].notna() & (expected_next != checked["next_mode"])).sum())
            print(f"  decisions.csv: missing rows={missing}, current-mode mismatches={mode_error}, next-mode mismatches={next_error}")
            if missing or mode_error or next_error:
                print("  FAIL: logged decisions do not fully match active modes")
    else:
        print("  WARNING: decisions.csv absent; can't confirm actions actually caused mode switches")

    audit = []
    for rec in change.itertuples(index=False):
        rid, seed, round_num = int(rec.run_id), int(rec.seed), int(rec.round)
        source, target = rec.mode, rec.next_mode
        history = joined[(joined["run_id"] == rid) & (joined["seed"] == seed)]
        last10 = history[(history["round"].between(round_num - 9, round_num)) & (history["mode"] == "centralized")]
        last5 = history[(history["round"].between(round_num - 4, round_num)) & (history["mode"] == "decentralized")]
        stable = len(last10) == 10 and int((last10["rent_pct"] >= 85).sum()) >= 8
        crater = len(last5) == 5 and int((last5["rent_pct"] < 70).sum()) >= 3
        high = rec.total > 36 * 1.15
        reason = "other / not identifiable"
        if source == "centralized" and target == "decentralized":
            reason = "stable high rent" if stable else "ineffective/underinvestment/other"
        elif source == "decentralized" and target == "centralized":
            reason = "rent crater" if crater else ("high investment" if high else "other")
        audit.append({
            "run_id": rid, "seed": seed, "decision_round": round_num,
            "new_mode_starts_round": round_num + 1,
            "from_mode": source, "to_mode": target,
            "mean_last_10_centralized_rent": float(last10["rent_pct"].mean()) if len(last10) == 10 else float("nan"),
            "centralized_stable_signal": stable,
            "decentralized_crater_signal": crater,
            "investment_high_this_round": high,
            "rent_pct_at_switch": rec.rent_pct,
            "inferred_reason": reason,
        })
    transitions = pd.DataFrame(audit)
    if not transitions.empty:
        print("  Retrospective reasons for transitions (based on observed outcomes):")
        for reason, num in transitions["inferred_reason"].value_counts().items():
            print(f"    {reason}: {num}")
    print("  NOTE: inferred reasons cannot prove which STRIPS action fired. Log the action/state for proof.")
    return usage, transitions, decisions


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path("gametheory/results"))
    parser.add_argument("--runs", type=int, default=30)
    parser.add_argument("--rounds", type=int, default=300)
    parser.add_argument("--scenarios", nargs="+", default=list(DEFAULT_SCENARIOS),
                        help="Which scenario directories to check (missing directories skipped)")
    parser.add_argument("--out", type=Path, default=None,
                        help="CSV output dir; defaults to <root>/verification")
    args = parser.parse_args()

    root = args.root
    out = args.out or root / "verification"
    out.mkdir(parents=True, exist_ok=True)
    print(f"Results directory: {root.resolve()}")
    print(f"Expected: {args.runs} independent seeds, {args.rounds} rounds each")
    print("Distance = |total group investment - 36| (also reports per-agent |average - 4.5|)")

    good = {}
    bad = {}
    all_metrics = []
    for scenario in args.scenarios:
        path = root / scenario / "rounds.csv"
        if not path.exists():
            print(f"\n{scenario}: SKIPPED (missing {path})")
            continue
        print(f"\n=== {scenario.upper()} ===")
        try:
            df = read_csv(path, ROUND_COLS)
            for col in ROUND_COLS[3:]:
                df[col] = pd.to_numeric(df[col], errors="raise").astype(float)
            problems = validate_rounds(scenario, df, args.runs, args.rounds)
            if problems:
                bad[scenario] = problems
                continue
            good[scenario] = df
            all_metrics.append(per_run_metrics(scenario, df))
        except (ValueError, KeyError, pd.errors.ParserError, pd.errors.EmptyDataError) as exc:
            print(f"  FAIL: {exc}")
            bad[scenario] = [str(exc)]

    if not all_metrics:
        raise SystemExit("\nNo valid scenario data. Fix the validation errors before comparing results.")

    metrics = pd.concat(all_metrics, ignore_index=True)
    metrics.to_csv(out / "per_run_metrics.csv", index=False)
    print("\n=== PER-SCENARIO MEANS (over independent runs) ===")
    for name in good:
        subset = metrics[metrics["scenario"] == name]
        print(f"  {name:<16} rent_pct={subset['mean_rent_pct'].mean():7.2f}% "
              f"abs_dist_total={subset['mean_abs_distance_total'].mean():6.2f} "
              f"abs_dist_per_agent={subset['mean_abs_distance_per_agent'].mean():5.2f}")

    if "adaptive" in good:
        comparisons, per_pair = compare_scenarios(metrics, list(good))
        if not comparisons.empty:
            comparisons.to_csv(out / "paired_comparisons.csv", index=False)
        if not per_pair.empty:
            per_pair.to_csv(out / "paired_run_differences.csv", index=False)
        usage, transitions, _ = audit_modes(good["adaptive"], root)
        if not usage.empty:
            usage.to_csv(out / "adaptive_mode_usage.csv", index=False)
        if not transitions.empty:
            transitions.to_csv(out / "adaptive_transitions.csv", index=False)
    else:
        print("\nWARNING: adaptive data invalid/missing, so no paired comparisons or mode audit possible")

    print(f"\nCSV audit files saved to {out.resolve()}")
    if bad:
        print("WARNING: INVALID scenarios excluded from all statistical comparisons: " + ", ".join(bad))
    print("Reminder: significance tests use independent RUN-level paired differences, not 300x30 correlated rounds.")


if __name__ == "__main__":
    main()
