#!/usr/bin/env python3
"""Sanity checks for adaptive v2 output; run from repository root."""
import argparse
from pathlib import Path
import pandas as pd

ap = argparse.ArgumentParser()
ap.add_argument('--root', default='gametheory/results/adaptive')
ap.add_argument('--rounds', type=int, default=300)
a = ap.parse_args()
root = Path(a.root)

def csv(name, cols, required=True):
    path = root / name
    if not path.exists():
        if required:
            raise FileNotFoundError(path)
        return pd.DataFrame(columns=cols)
    d = pd.read_csv(path, header=None, names=cols)
    return d

keys=['run_id','seed']
rounds = csv('rounds.csv', keys+['round','total','average','rent','rent_pct'])
agents = csv('agents.csv', keys+['round','agent','strategy','bid','market1','market2','payoff'])
modes = csv('modes.csv',keys+['round','mode'])
decisions = csv('decisions.csv',keys+['round','current','proposed','applied','age','optimal_count'])
choices = csv('central_strategy_choices.csv',keys+['decision_round','central_strategy','predicted_total','predicted_rent'],False)
renew = csv('recoordination.csv',keys+['decision_round','reason'],False)
assert not rounds.duplicated(keys+['round']).any(), 'Duplicate round outputs'
assert not agents.duplicated(keys+['round','agent']).any(), 'Duplicate agent outputs'
assert not modes.duplicated(keys+['round']).any(), 'Duplicate mode outputs'
assert not decisions.duplicated(keys+['round']).any(), 'Duplicate decision outputs'
assert set(modes['mode'].unique()) <= {'none','centralized','decentralized','coalition'}
counts=rounds.groupby(keys)['round'].agg(['min','max','nunique'])
assert (counts['min']==1).all(), counts
assert (counts['max']==a.rounds).all(), counts
assert (counts['nunique']==a.rounds).all(), counts
assert len(agents)==len(rounds)*8, (len(agents),len(rounds))
assert len(modes)==len(rounds)==len(decisions), 'Mode and decisions records incomplete'
assert agents.groupby(keys+['round'])['agent'].nunique().eq(8).all(), 'Missing agent bids'
merged=choices.copy()
if len(choices):
    assert not choices.duplicated(keys+['decision_round']).any(), 'Duplicate choices'
    assert not renew.duplicated(keys+['decision_round']).any(), 'Duplicate renewals'
    assert len(renew)==len(choices), 'A renewal should have exactly one successful strategy choice'
    merged['round']=merged['decision_round']+1
    merged=merged.merge(rounds[keys+['round','total','rent']],on=keys+['round'],how='left',validate='one_to_one')
    merged=merged.merge(modes.rename(columns={'mode':'next_mode'}),on=keys+['round'],how='left',validate='one_to_one')
    valid=merged[merged['next_mode']=='centralized'].dropna(subset=['total'])
    mismatch=(valid['predicted_total']-valid['total']).abs().gt(1e-6)
    assert not mismatch.any(), f'Incorrect next-round forecasts: {int(mismatch.sum())}'
    print(f'Central coordination events: {len(choices)}; next-round forecasts verified: {len(valid)}')
else:
    print('No central coordination events recorded (may be valid if no centralized rounds).')
print('Runs:',len(counts),'rounds:',len(rounds),'agents:',len(agents))
print('Mode shares (%):\n', (100*modes['mode'].value_counts(normalize=True)).round(1).to_string())
print('Mean group rent:',round(rounds['rent_pct'].mean(),2),'% of optimum')
print('VALIDATION PASSED')
