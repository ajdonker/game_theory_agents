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


# contrib quota
# subsidize contrib (kind of doesnt make sense as it makes resource out of thin air)
# reward long term contributor with reduced quota 
# penalize repeated free rider 
# change resource distrib to coalition / change coalition 