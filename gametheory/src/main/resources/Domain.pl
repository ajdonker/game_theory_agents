:- consult('strips.pl').

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CENTRAL COMMUNICATION DOMAIN
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% If the planner has collected all strategy evaluations and
% knows which strategy is collectively best, it can enforce it.

action(
    enforce_strategy(S),

    if([
        evaluations_collected,
        best_strategy(S)
    ]),

    +([
        strategy_enforced(S)
    ]),

    -([]),

    where(true)
).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Wrapper called from Jason/Kotlin
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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