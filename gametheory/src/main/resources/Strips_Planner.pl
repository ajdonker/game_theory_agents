 action(
    enforce_strategy(S),
    'if'([evaluations_collected, best_strategy(S)]),
    '+'([strategy_enforced(S)]),
   '-'([]),
    where(true)
).

 central_plan(BestStrategy, Plan) :-
    strips(
        [evaluations_collected, best_strategy(BestStrategy)],
        [strategy_enforced(BestStrategy)],
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
    'if'([mode_decentralized, investment_low, dispersion_low]),
    '+'([investment_optimal]),
    '-'([investment_low]),
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

% Investment already optimal: disable intervention
intervention_plan(InitState, Plan) :-
    member(investment_optimal, InitState),
    !,
    strips(
        InitState,
        [investment_optimal, mode_none],
        Plan
    ).

% Investment not optimal: achieve optimal investment
intervention_plan(InitState, Plan) :-
    strips(
        InitState,
        [investment_optimal],
        Plan
    ).
