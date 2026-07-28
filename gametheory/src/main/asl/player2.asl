/* Possible actions */
available(cooperate).
available(defect).

/*
 * payoff(MyAction, OpponentAction, MyPayoff)
 */
payoff(cooperate, cooperate, -1).
payoff(cooperate, defect,    -12).
payoff(defect,    cooperate, 0).
payoff(defect,    defect,    -8).


/*
 * Defect strictly dominates cooperate when it produces
 * a greater payoff against every possible opponent action.
 */
strictly_dominates(defect, cooperate) :-
    payoff(defect, cooperate, DefectVsCooperate) &
    payoff(cooperate, cooperate, CooperateVsCooperate) &
    DefectVsCooperate > CooperateVsCooperate &

    payoff(defect, defect, DefectVsDefect) &
    payoff(cooperate, defect, CooperateVsDefect) &
    DefectVsDefect > CooperateVsDefect.


/*
 * The reverse check allows the same reasoning structure
 * to work with a different payoff matrix.
 */
strictly_dominates(cooperate, defect) :-
    payoff(cooperate, cooperate, CooperateVsCooperate) &
    payoff(defect, cooperate, DefectVsCooperate) &
    CooperateVsCooperate > DefectVsCooperate &

    payoff(cooperate, defect, CooperateVsDefect) &
    payoff(defect, defect, DefectVsDefect) &
    CooperateVsDefect > DefectVsDefect.


/* Initial goal */
!choose_action.


/* Eliminate cooperate when defect strictly dominates it */
+!choose_action : strictly_dominates(defect, cooperate)
<-
    -available(cooperate);
    +eliminated(cooperate);
    +chosen(defect);

    .print("Cooperate was eliminated.");
    .print("The agent chooses DEFECT.").


/* Eliminate defect when cooperate strictly dominates it */
+!choose_action : strictly_dominates(cooperate, defect)
<-
    -available(defect);
    +eliminated(defect);
    +chosen(cooperate);

    .print("Defect was eliminated.");
    .print("The agent chooses COOPERATE.").


/* Some games have no strictly dominant action */
+!choose_action :
    not strictly_dominates(defect, cooperate) &
    not strictly_dominates(cooperate, defect)
<-
    .print("No strictly dominant action exists.");
    .print("Another decision rule is required.").