action(
    enforce_bid(B),
    'if'([
        evaluations_collected,
        best_bid(B)
    ]),
    '+'([
        bid_enforced(B)
    ]),
    '-'([]),
    where(true)
).

action(
    enable_coalitions,
    'if'([mode_decentralized, investment_low, dispersion_high]),
    '+'([mode_coalition]),
    '-'([mode_decentralized]),
    where(true)
).
action(
    disable_coalitions,
    'if'([mode_coalition, investment_low, dispersion_low]),
    '+'([mode_decentralized]),
    '-'([mode_coalition]),
    where(true)
).
action(
    enable_centralized,
    'if'([mode_none, investment_high]),
    '+'([mode_centralized]),
    '-'([mode_none]),
    where(true)
).
action(
    switch_decentralized_to_centralized,
    'if'([mode_decentralized, investment_high]),
    '+'([mode_centralized]),
    '-'([mode_decentralized]),
    where(true)
).
action(
    switch_coalition_to_centralized,
    'if'([mode_coalition, investment_high]),
    '+'([mode_centralized]),
    '-'([mode_coalition]),
    where(true)
).
action(
    enable_decentralized,
    'if'([mode_none, investment_low]),
    '+'([mode_decentralized]),
    '-'([mode_none]),
    where(true)
).
action(
    switch_centralized_to_decentralized,
    'if'([mode_centralized, investment_low]),
    '+'([mode_decentralized]),
    '-'([mode_centralized]),
    where(true)
).
action(
    switch_coalition_to_decentralized,
    'if'([mode_coalition, investment_low, dispersion_low]),
    '+'([mode_decentralized]),
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

desired_mode(State, mode_coalition) :-
    member(investment_low, State),
    member(dispersion_high, State),
    member(mode_decentralized, State),
    !.
desired_mode(State, mode_coalition) :-
    member(investment_low, State),
    member(dispersion_high, State),
    member(mode_coalition, State),
    !.
desired_mode(State, mode_centralized) :- member(investment_high, State), !.
desired_mode(State, mode_decentralized) :- member(investment_low, State), !.
desired_mode(State, mode_none) :- member(investment_optimal, State), !.

intervention_plan(InitState, Plan) :-
    desired_mode(InitState, GoalMode),
    strips(InitState, [GoalMode], Plan).
