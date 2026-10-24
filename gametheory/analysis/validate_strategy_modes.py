"""Validate the two strategy-based communication scenarios. Run from repo root."""
from pathlib import Path
import argparse
import pandas as pd

p = argparse.ArgumentParser()
p.add_argument("scenario", choices=["decentralized_strat", "coalition_strat"])
p.add_argument("--root", default="gametheory/results")
a = p.parse_args()
root = Path(a.root) / a.scenario

def read(name, columns, required=True):
    file = root / name
    if not file.is_file():
        if required:
            raise SystemExit(f"Missing {file}")
        return pd.DataFrame(columns=columns)
    if file.stat().st_size == 0:
        return pd.DataFrame(columns=columns)
    return pd.read_csv(file, header=None, names=columns)

rounds = read('rounds.csv', ['run_id','seed','round','total','average','rent','rent_pct'])
agents = read('agents.csv', ['run_id','seed','round','agent','strategy','bid','m1','m2','payoff'])
pools = read('strategy_pools.csv', ['run_id','seed','agent','s1','s2','s3','s4'])
communication = read('communication.csv', ['run_id','seed','round','agent','strategy','votes','own_mean'], required=False)

print('Scenario:', a.scenario)
print('Runs:', rounds[['run_id','seed']].drop_duplicates().shape[0])
print('Rounds:', len(rounds), 'Agent records:', len(agents))
print('Duplicates: rounds=', rounds.duplicated(['run_id','seed','round']).sum(),
      'agents=', agents.duplicated(['run_id','seed','round','agent']).sum())
counts = rounds.groupby(['run_id','seed']).round.nunique()
print('Rounds per run:', counts.to_dict())
assert rounds.duplicated(['run_id','seed','round']).sum() == 0
assert agents.duplicated(['run_id','seed','round','agent']).sum() == 0
assert all((counts == 100).tolist()), 'Incomplete runs'
assert len(agents) == 8 * len(rounds)
assert len(pools) == 8 * len(counts)
assert not pools.duplicated(['run_id','seed','agent']).any()
assert not communication.duplicated(['run_id','seed','round','agent']).any()

# Each decision must belong to its own randomly initialized four-strategy pool.
if not communication.empty:
    comm = communication.merge(pools, on=['run_id','seed','agent'],
                               how='left', validate='many_to_one')
    in_pool = comm.apply(lambda x: x.strategy in [x.s1,x.s2,x.s3,x.s4], axis=1)
    print('Out-of-pool strategy choices:', (~in_pool).sum())
    assert in_pool.all()
    assert (comm['round'] % 5 == 0).all()
    print('Communication decisions:', len(comm))

if a.scenario == 'decentralized_strat':
    expected = 20 * 8 * len(counts)
    print('Expected decentralized decisions:', expected)
    assert len(communication) == expected
else:
    links = read('coalitions.csv', ['run_id','seed','round','agent','peer','bid','peer_bid','trust','peer_trust'],required=False)
    print('Coalition directed links:', len(links))
    if not links.empty:
        assert (links['round'] % 5 == 0).all()
        assert (links['trust'].between(0,1)).all()
        assert (links['peer_trust'].between(0,1)).all()

print('Validation passed.')
