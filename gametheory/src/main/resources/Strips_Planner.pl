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

action (
    enable_coalitions,
    'if'([coalitions_disabled]),
    '+'([coalitions_enabled]),
    '-'([coalitions_disabled]),
    where(true)
).
action(
    disable_coalitions,
    'if'([coalitions_enabled]),
    '+'([coalitions_disabled]),
    '-'([coalitions_enabled]),
    where(true)
).
action(
    enable_centralized,
    'if'([mode_none]),
    '+'([mode_centralized]),
    '-'([mode_none]),
    where(true)
).
action(
    disable_centralized,
    'if'([mode_centralized]),
    '+'([mode_none]),
    '-'([mode_centralized]),
    where(true)
).
action(
    enable_decentralized,
    'if'([mode_none]),
    '+'([mode_decentralized]),
    '-'([mode_none]),
    where(true)
).
action(
    disable_decentralized,
    'if'([mode_decentralized]),
    '+'([mode_none]),
    '-'([mode_decentralized]),
    where(true)
).

% =====================================
% SELECT GOAL FROM CURRENT STATE
% =====================================
desired_mode(State, mode_none) :- member(investment_optimal, State), !.
desired_mode(State, mode_centralized) :- member(investment_high, State), member(performance_low, State), !.
desired_mode(State, mode_decentralized) :- member(investment_low, State), member(performance_high, State), !.
desired_mode(State, mode_none) :- member(investment_high, State), member(performance_high, State), !.
desired_mode(State, mode_coalition) :- member(investment_high, State), member(dispersion_high, State), !.



intervention_plan(InitState, Plan) :-
    desired_mode(InitState, GoalMode),
    strips(InitState, [GoalMode], Plan).
