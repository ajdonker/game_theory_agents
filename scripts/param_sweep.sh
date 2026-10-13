#!/usr/bin/env bash

set -euo pipefail

# ---------------------------------------------------------
# Paths
# ---------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
GAMETHEORY_DIR="$ROOT_DIR/gametheory"

AGENT="$GAMETHEORY_DIR/src/main/asl/coalition_agent.asl"
PLANNER="$GAMETHEORY_DIR/src/main/asl/coalition_planner.asl"

# The ASL currently writes here
LIVE_RESULTS="$GAMETHEORY_DIR/results/coalition"

# Permanent storage for every parameter combination
SWEEP_RESULTS="$GAMETHEORY_DIR/results/coalition_sweep"

mkdir -p "$LIVE_RESULTS"
mkdir -p "$SWEEP_RESULTS"


# ---------------------------------------------------------
# Parameter values to test
# ---------------------------------------------------------

PEER_VALUES=(1 2 3 4)
RATE_VALUES=(5 10 15)


# ---------------------------------------------------------
# Backup original ASL files
# ---------------------------------------------------------

cp "$AGENT" "$AGENT.sweep_backup"
cp "$PLANNER" "$PLANNER.sweep_backup"

cleanup() {
    mv "$AGENT.sweep_backup" "$AGENT"
    mv "$PLANNER.sweep_backup" "$PLANNER"
}

trap cleanup EXIT


# ---------------------------------------------------------
# Parameter sweep
# ---------------------------------------------------------

for PEERS in "${PEER_VALUES[@]}"
do
    for RATE in "${RATE_VALUES[@]}"
    do

        echo ""
        echo "======================================================"
        echo " MAX PEERS = $PEERS | COALITION RATE = $RATE"
        echo "======================================================"

        # -------------------------------------------------
        # Inject coalition parameters into agent
        # -------------------------------------------------

        sed -i -E \
            "s/^max_coalition_peers\([0-9]+\)\./max_coalition_peers($PEERS)./" \
            "$AGENT"

        sed -i -E \
            "s/^coalitioning_rate\([0-9]+\)\./coalitioning_rate($RATE)./" \
            "$AGENT"


        # -------------------------------------------------
        # Clear results from previous configuration
        # -------------------------------------------------

        rm -f "$LIVE_RESULTS/rounds.csv"
        rm -f "$LIVE_RESULTS/agents.csv"
        rm -f "$LIVE_RESULTS/strategies.csv"
        rm -f "$LIVE_RESULTS/coalitions.csv"
        rm -f "$LIVE_RESULTS/baseline_30_summary.csv"


        # -------------------------------------------------
        # Run same 30 seeds
        # -------------------------------------------------

        for RUN in $(seq 1 30)
        do
            SEED=$((41 + RUN))

            echo ""
            echo "--------------------------------------"
            echo " PEERS $PEERS | RATE $RATE"
            echo " RUN $RUN / 30 | SEED $SEED"
            echo "--------------------------------------"

            sed -i -E \
                "s/^run_id\([0-9]+\)\./run_id($RUN)./" \
                "$PLANNER"

            sed -i -E \
                "s/^seed\([0-9]+\)\./seed($SEED)./" \
                "$PLANNER"

            "$ROOT_DIR/gradlew" \
                -p "$ROOT_DIR" \
                :gametheory:runCoalitionCommunication
        done


        # -------------------------------------------------
        # Run analysis so baseline_30_summary.csv is created
        # -------------------------------------------------

        python \
            "$GAMETHEORY_DIR/analysis/plots.py" \
            coalition


        # -------------------------------------------------
        # Save this configuration separately
        # -------------------------------------------------

        CONFIG_DIR="$SWEEP_RESULTS/peers_${PEERS}_rate_${RATE}"

        mkdir -p "$CONFIG_DIR"

        cp "$LIVE_RESULTS/rounds.csv" \
           "$CONFIG_DIR/rounds.csv"

        cp "$LIVE_RESULTS/agents.csv" \
           "$CONFIG_DIR/agents.csv"

        cp "$LIVE_RESULTS/strategies.csv" \
           "$CONFIG_DIR/strategies.csv"

        cp "$LIVE_RESULTS/baseline_30_summary.csv" \
           "$CONFIG_DIR/baseline_30_summary.csv"

        if [ -f "$LIVE_RESULTS/coalitions.csv" ]; then
            cp "$LIVE_RESULTS/coalitions.csv" \
               "$CONFIG_DIR/coalitions.csv"
        fi

        echo ""
        echo "Saved results to:"
        echo "$CONFIG_DIR"

    done
done


echo ""
echo "======================================================"
echo " PARAMETER SWEEP COMPLETE"
echo "======================================================"