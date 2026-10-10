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
    [coalitions_disabled],
    [coalitions_enabled],
    [coalitions_disabled]
).
central_plan(BestStrategy, Plan) :-
    InitState = [
        evaluations_collected,
        best_bid(BestBid)
    ],

    Goal = [
        bid_enforced(BestBid)
    ],

    strips(
        InitState,
        Goal,
        Plan
    ).