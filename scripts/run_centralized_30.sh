#!/usr/bin/env bash

set -euo pipefail
# .../game_theory_agents/scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .../game_theory_agents
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# .../game_theory_agents/gametheory
GAMETHEORY_DIR="$ROOT_DIR/gametheory"

PLANNER="$GAMETHEORY_DIR/src/main/asl/centralized_planner.asl"
RESULTS="$GAMETHEORY_DIR/results/centralized"

rm -f "$RESULTS/rounds.csv"
rm -f "$RESULTS/agents.csv"
rm -f "$RESULTS/strategies.csv"

# Keep a backup of the planner.
cp "$PLANNER" "$PLANNER.batch_backup"

# Restore original planner even if script is interrupted.
trap 'mv "$PLANNER.batch_backup" "$PLANNER"' EXIT

for RUN in $(seq 1 30)
do
    # Same seeds as no-communication: 42 ... 71
    SEED=$((41 + RUN))

    echo ""
    echo "======================================"
    echo " CENTRALIZED RUN $RUN / 30     SEED $SEED"
    echo "======================================"

    sed -i -E \
        "s/^run_id\([0-9]+\)\./run_id($RUN)./" \
        "$PLANNER"

    sed -i -E \
        "s/^seed\([0-9]+\)\./seed($SEED)./" \
        "$PLANNER"

    
    "$ROOT_DIR/gradlew" -p "$ROOT_DIR" :gametheory:runCentralizedCommunication
done

echo ""
echo "======================================"
echo " ALL 30 CENTRALIZED RUNS COMPLETE"
echo "======================================"