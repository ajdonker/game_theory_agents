#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
MODULE="$ROOT_DIR/gametheory"
PLANNER="$MODULE/src/main/asl/coalition_strat_planner.asl"
RESULTS="$MODULE/results/coalition_strat"
TASK="runCoalitionStrategyCommunication"
[[ -f "$PLANNER" ]] || { echo "Missing $PLANNER" >&2; exit 1; }
mkdir -p "$RESULTS"
rm -f "$RESULTS"/*.csv
cp "$PLANNER" "$PLANNER.batch_backup"
trap 'mv "$PLANNER.batch_backup" "$PLANNER"' EXIT
for RUN in $(seq 1 30); do
    SEED=$((41 + RUN))
    sed -i -E "s/^run_id\([0-9]+\)\./run_id($RUN)./" "$PLANNER"
    sed -i -E "s/^seed\([0-9]+\)\./seed($SEED)./" "$PLANNER"
    echo "coalition_strat: run=$RUN seed=$SEED"
    "$ROOT_DIR/gradlew" -p "$ROOT_DIR" ":gametheory:$TASK"
    EXPECTED=$((RUN * 100))
    ACTUAL=$(wc -l < "$RESULTS/rounds.csv")
    if (( ACTUAL != EXPECTED )); then
        echo "ERROR: expected $EXPECTED rounds, got $ACTUAL" >&2
        exit 1
    fi
done
