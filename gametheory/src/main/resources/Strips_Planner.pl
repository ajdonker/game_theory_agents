action(
    enforce_strategy(S),
    'if'([
        evaluations_collected,
        best_strategy(S)
    ]),
    '+'([
        strategy_enforced(S)
    ]),
    '-'([]),
    where(true)
).

central_plan(BestStrategy, Plan) :-
    InitState = [
        evaluations_collected,
        best_strategy(BestStrategy)
    ],

    Goal = [
        strategy_enforced(BestStrategy)
    ],

    strips(
        InitState,
        Goal,
        Plan
    ).