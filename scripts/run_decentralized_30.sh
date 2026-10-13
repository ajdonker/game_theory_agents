#!/usr/bin/env bash

set -euo pipefail

# .../game_theory_agents/scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .../game_theory_agents
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# .../game_theory_agents/gametheory
GAMETHEORY_DIR="$ROOT_DIR/gametheory"

PLANNER="$GAMETHEORY_DIR/src/main/asl/decentralized_planner.asl"
RESULTS="$GAMETHEORY_DIR/results/decentralized"

mkdir -p "$RESULTS"

rm -f "$RESULTS/rounds.csv"
rm -f "$RESULTS/agents.csv"
rm -f "$RESULTS/strategies.csv"
# rm -f "$RESULTS/coalitions.csv"

cp "$PLANNER" "$PLANNER.batch_backup"

trap 'mv "$PLANNER.batch_backup" "$PLANNER"' EXIT

for RUN in $(seq 1 30)
do
    SEED=$((41 + RUN))

    echo ""
    echo "======================================"
    echo " DECENTRALIZED RUN $RUN / 30     SEED $SEED"
    echo "======================================"

    sed -i -E \
        "s/^run_id\([0-9]+\)\./run_id($RUN)./" \
        "$PLANNER"

    sed -i -E \
        "s/^seed\([0-9]+\)\./seed($SEED)./" \
        "$PLANNER"

    "$ROOT_DIR/gradlew" -p "$ROOT_DIR" :gametheory:runDecentralizedCommunication
done

echo ""
echo "======================================"
echo " ALL 30 DECENTRALIZED RUNS COMPLETE"
echo "======================================"