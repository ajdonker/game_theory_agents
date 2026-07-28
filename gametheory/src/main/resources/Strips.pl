strips(InitialState, GoalList, []) :-
    subseteq(GoalList, InitialState).