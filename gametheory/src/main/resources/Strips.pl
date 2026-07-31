strips(InitialState, GoalList, []) :-
    subseteq(GoalList, InitialState).


Action: grant-resource(A, R)
    Preconditions: 
        requests(A, R)
        meets-contribution-quota(A)
        stock-above-minimum(R)
    Effects:
        has-resource(A, R)
        decrease-stock(R)
        not requests(A, R)        
