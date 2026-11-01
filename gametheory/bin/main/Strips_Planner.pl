% =========================================
% CENTRALIZED BID ENFORCEMENT
% =========================================

action(
    enforce_bid(Bid),
    'if'([evaluations_collected, best_bid(Bid)]),
    '+'([bid_enforced(Bid)]),
    '-'([]),
    where(true)
).

central_plan(Bid, Plan) :-
    number(Bid),
    strips(
        [evaluations_collected, best_bid(Bid)],
        [bid_enforced(Bid)],
        Plan
    ).



% =========================================
% HIGH INVESTMENT -> CENTRALIZED
% =========================================
action(
    enable_centralized,
    'if'([mode_none, investment_high]),
    '+'([mode_centralized, investment_optimal]),
    '-'([mode_none, investment_high]),
    where(true)
).
action(
    switch_decentralized_to_centralized,
    'if'([mode_decentralized, investment_high]),
    '+'([mode_centralized, investment_optimal]),
    '-'([mode_decentralized, investment_high]),
    where(true)
).
action(
    switch_coalition_to_centralized,
    'if'([mode_coalition, investment_high]),
    '+'([mode_centralized, investment_optimal]),
    '-'([mode_coalition, investment_high]),
    where(true)
).
action(
    maintain_centralized,
    'if'([mode_centralized, investment_high]),
    '+'([investment_optimal]),
    '-'([investment_high]),
    where(true)
).
% =========================================
% LOW INVESTMENT, LOW DISPERSION
% -> DECENTRALIZED
% =========================================
% Centralized has achieved sustained high performance.
% Give decentralized communication a trial.
action(
    trial_decentralized_after_stability,
    'if'([
        mode_centralized,
        centralized_stable
    ]),
    '+'([mode_decentralized]),
    '-'([mode_centralized]),
    where(true)
).

% Decentralized performance has deteriorated.
% Restore centralized coordination.
action(
    recover_centralized,
    'if'([
        mode_decentralized,
        decentralized_crater
    ]),
    '+'([mode_centralized]),
    '-'([mode_decentralized]),
    where(true)
).
action(
    enable_decentralized,
    'if'([mode_none, investment_low, dispersion_low]),
    '+'([mode_decentralized, investment_optimal]),
    '-'([mode_none, investment_low]),
    where(true)
).
action(
    switch_centralized_to_decentralized,
    'if'([mode_centralized, investment_low, dispersion_low]),
    '+'([mode_decentralized, investment_optimal]),
    '-'([mode_centralized, investment_low]),
    where(true)
).
action(
    switch_coalition_to_decentralized,
    'if'([mode_coalition, investment_low, dispersion_low]),
    '+'([mode_decentralized, investment_optimal]),
    '-'([mode_coalition, investment_low]),
    where(true)
).
action(
maintain_decentralized,
    'if'([mode_decentralized]),
    '+'([investment_held]),
    '-'([]),
    where(true)
).
% =========================================
% LOW INVESTMENT, HIGH DISPERSION
% -> COALITIONS
% =========================================
% First establish decentralized communication.
action(
    prepare_coalitions_from_none,
    'if'([mode_none, investment_low, dispersion_high]),
    '+'([mode_decentralized]),
    '-'([mode_none]),
    where(true)
).
action(
    prepare_coalitions_from_centralized,
    'if'([mode_centralized, investment_low, dispersion_high]),
    '+'([mode_decentralized]),
    '-'([mode_centralized]),
    where(true)
).
action(
    enable_coalitions,
    'if'([mode_decentralized, investment_low, dispersion_high]),
    '+'([mode_coalition, investment_optimal]),
    '-'([mode_decentralized, investment_low]),
    where(true)
).
action(
    maintain_coalitions,
    'if'([mode_coalition, investment_low, dispersion_high]),
    '+'([investment_optimal]),
    '-'([investment_low]),
    where(true)
).
action(
    disable_coalitions,
    'if'([mode_coalition, investment_optimal, dispersion_low]),
    '+'([mode_none]),
    '-'([mode_coalition]),
    where(true)
).
action(
    disable_centralized,
    'if'([mode_centralized, investment_optimal]),
    '+'([mode_none]),
    '-'([mode_centralized]),
    where(true)
).
action(
    disable_decentralized,
    'if'([mode_decentralized, investment_optimal]),
    '+'([mode_none]),
    '-'([mode_decentralized]),
    where(true)
).
action(
    disable_coalition_for_optimal_investment,
    'if'([mode_coalition, investment_optimal]),
    '+'([mode_none]),
    '-'([mode_coalition]),
    where(true)
).
% =========================================
% STAGNANT INTERVENTION PERFORMANCE
% -> CHANGE INTERVENTION
% =========================================
% First run centralized and detect ineffective.
action(
    trial_decentralized,
    'if'([mode_centralized,
          centralized_ineffective,
          dispersion_low]),
    '+'([mode_decentralized]),
    '-'([mode_centralized]),
    where(true)
).

action(
    trial_coalition,
    'if'([mode_centralized,
          centralized_ineffective,
          dispersion_high]),
    '+'([mode_coalition]),
    '-'([mode_centralized]),
    where(true)
).


% 1. Decentralized performance collapsed.
% Return to centralized.
intervention_plan(State, Plan) :-
    member(mode_decentralized, State),
    member(decentralized_crater, State),
    !,
    strips(State, [mode_centralized], Plan).


% 2. Decentralized is overinvesting again.
% Return to centralized.
intervention_plan(State, Plan) :-
    member(mode_decentralized, State),
    member(investment_high, State),
    !,
    strips(State, [mode_centralized], Plan).


% 3. Investment is optimal.
% Allow decentralized to finish.
intervention_plan(State, Plan) :-
    member(mode_decentralized, State),
    member(investment_optimal, State),
    !,
    strips(State, [mode_none], Plan).


% 4. Otherwise, keep decentralized.
intervention_plan(State, Plan) :-
    member(mode_decentralized, State),
    !,
    strips(State, [investment_held], Plan).

% Centralized failed, agents have similar bids.
intervention_plan(State, Plan) :-
    member(mode_centralized, State),
    member(investment_high, State),
    member(centralized_ineffective, State),
    member(dispersion_low, State),
    !,
    strips(State, [mode_decentralized], Plan).

% Centralized failed, agents have dispersed bids.
intervention_plan(State, Plan) :-
    member(mode_centralized, State),
    member(investment_high, State),
    member(centralized_ineffective, State),
    member(dispersion_high, State),
    !,
    strips(State, [mode_coalition], Plan).
% Investment optimal: back to no intervention.
intervention_plan(State, Plan) :-
    member(investment_optimal, State),
    !,
    strips(State, [mode_none], Plan).

% Overinvestment: centralized coordination.
intervention_plan(State, Plan) :-
    member(investment_high, State),
    !,
    strips(State, [mode_centralized], Plan).

% Underinvestment with high dispersion: coalitions.
intervention_plan(State, Plan) :-
    member(investment_low, State),
    member(dispersion_high, State),
    !,
    strips(State, [mode_coalition], Plan).

% Underinvestment with low dispersion: decentralized communication.
intervention_plan(State, Plan) :-
    member(investment_low, State),
    member(dispersion_low, State),
    !,
    strips(State, [mode_decentralized], Plan).

