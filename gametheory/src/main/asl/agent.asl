need(resource, 2).
obtained(resource, 0).
strategy(undecided).
benefit_per_unit(5).
contribution_cost(2).
unmet_penalty(4).
current_round(0).
current_quota(0).
// contribution_quota(resource, 1).
//!start. 
// !keep_resource_in_check as the starting goal then request as plan

// is there a point in making trying to req a resource a test goal 
// +!start <-
//     .println("Starting resource acquisition...");
//     //.send(planner, achieve, obtain(resource)).
//     !satisfy_need(resource).

+start_round(Round, Required)[source(planner)]
<- 
    -current_round(_);
    +current_round(Round);

    -current_quota(_);
    +current_quota(Required);

    -strategy(_);
    +strategy(undecided);

    .println("Round ", Round, " Received contribution quota: ", Required);
    //!choose_contribution(Round).
    !choose_strategy(Round).


+!choose_strategy(Round)
<- 
    !estimate_utility(cooperating, Round);
    !estimate_utility(free_riding, Round);
    !select_strategy(Round).

+!select_strategy(Round)
    : expected_utility(Round, cooperating, CoopUtility)
    & expected_utility(Round, free_riding, FreeRidingUtility)
    & CoopUtility > FreeRidingUtility
<-
    -strategy(_);
    +strategy(cooperating);  
    .println(
        "Round ", Round,
        ": EU(cooperate) = ", CoopUtility,
        ", EU(free ride) = ", FreeRidingUtility,
        " -> COOPERATE"
    );
    !set_contribution_choice(Round, 1). 

+!select_strategy(Round)
    : expected_utility(Round, cooperating, CoopUtility)
    & expected_utility(Round, free_riding, FreeRidingUtility)
    & FreeRidingUtility >= CoopUtility
<-
    -strategy(_);
    +strategy(free_riding);  
    .println(
        "Round ", Round,
        ": EU(cooperate) = ", CoopUtility,
        ", EU(free ride) = ", FreeRidingUtility,
        " -> FREE_RIDE"
    );
    !set_contribution_choice(Round, 0).

+! estimate_utility(cooperating, Round)
    : need(resource, Need)
    & current_quota(Required)
    & Required <= 1
    & benefit_per_unit(Benefit)
    & contribution_cost(Cost)
    & unmet_penalty(Penalty)
<- 
    ExpectedObtained = Need;
    ExpectedUnmet = 0;

    Utility = Benefit * ExpectedObtained - Cost - Penalty * ExpectedUnmet;

    +expected_utility(Round, cooperating, Utility).
    
+!estimate_utility(cooperating, Round)
    : need(resource, Need)
    & current_quota(Required)
    & Required > 1
    & contribution_cost(Cost)
    & unmet_penalty(Penalty)
<-
    Utility = 0 - Cost - Penalty * Need;

    +expected_utility(Round, cooperating, Utility).

+!estimate_utility(free_riding, Round)
    : need(resource, Need)
    & current_quota(0)
    & benefit_per_unit(Benefit)
<-
    Utility = Benefit * Need;

    +expected_utility(Round, free_riding, Utility).

+!estimate_utility(free_riding, Round)
    : need(resource, Need)
    & current_quota(Required)
    & Required > 0
    & unmet_penalty(Penalty)
<-
    Utility = 0 - Penalty * Need;

    +expected_utility(Round, free_riding, Utility).    
// +!choose_contribution(Round)
//     : strategy(cooperating)
// <-
//     .println("Round ", Round, ": strategy = cooperating. Contributing 1.");
//     .send(planner, achieve, contribute(resource, 1)).


+! set_contribution_choice(Round, Amount)
<-
    -chosen_contribution(Round, _);
    +chosen_contribution(Round, Amount);

    !submit_contribution(Round, Amount).

+! submit_contribution(Round, Amount)
<-
    .send(planner, achieve, contribute(resource, Amount)).
        
+!satisfy_need(Resource) 
    : need(Resource, Required)
    & obtained(Resource, Current)
    & Current < Required

<- 
    .println(
        "REQUESTING RESOURCE: ", Resource,
        ". Obtained: ", Current, 
        ". Needed: ", Required
    );
    .send(planner, achieve, obtain(Resource)).


+!satisfy_need(Resource)
    : need(Resource, Required)
    & obtained(Resource, Current)
    & Current >= Required
<-
    .println(
        "RESOURCE NEED SATISFIED: ", Resource,
        ". Total obtained: ", Current
    );

    !use_resource(Resource). 

+!use_resource(Resource)
    : need(Resource, Required)
    & obtained(Resource, Current)
    & Current >= Required 
<-
    .println(
        "USING RESOURCE: ", Resource, 
        ". Amount Used: ", Current    
    );

    //!release_resource(Resource).
    // -obtained(Resource, Current);
    // +obtained(Resource, 0);
    // !finish_round.
    .send(planner, achieve, consume(Resource, Current)).

+!consumed(Resource, Amount)[source(planner)]
<-
    -obtained(Resource, _);
    +obtained(Resource, 0);

    .println(
        "RESOURCE CONSUMPTION CONFIRMED: ",
        Resource,
        ". Amount consumed: ",
        Amount
    );

    !finish_round.

// +! release_resource(Resource)
//     : obtained(Resource, Current)
//     & Current > 0
// <- 
//     .send(planner, achieve, release(Resource)).


// +! release_resource(Resource)
//     : obtained(Resource, 0)
// <-
//     !finish_round.


+! finish_round
    :current_round(Round)
<- 
    .println("FINISHED ROUND: ", Round);
    .send(planner, tell, round_finished(Round)).

+!release_denied(Resource)[source(planner)]
<-
    .println(
        "CANNOT RELEASE RESOURCE: ", Resource,
        ". Agent owns none."
    ).

// +!released(Resource, AvailableStock, RemainingOwned)[source(planner)]
// <-
//     -obtained(Resource, _);
//     +obtained(Resource, RemainingOwned);

//     .println(
//         "RESOURCE RELEASE CONFIRMED: ", Resource,
//         ". Remaining owned: ", RemainingOwned,
//         ". Available stock: ", AvailableStock
//     );
//     -released(Resource, AvailableStock, RemainingOwned);
//     !release_resource(Resource).

// // next handler can be removed 
+!granted(Resource, Remaining, TotalOwned)[source(planner)]
<-
    -obtained(Resource, _);
    +obtained(Resource, TotalOwned);

    .println(
        "RESOURCE GRANTED: ", Resource,
        ". Total owned: ", TotalOwned,
        ". Remaining stock: ", Remaining
    );
    -granted(Resource, Remaining, TotalOwned);
    !satisfy_need(Resource).
    
+!denied(Resource, Remaining)[source(planner)] 
    : obtained(Resource, Current)
    & need(Resource, Required)
<- 
    Unmet = Required - Current;
    -denied(Resource, Remaining);
    .println("RESOURCE DENIED: ", Resource,
        ". Obtained: ", Current,
        ". Unmet demand: ", Unmet,
        ". Available stock: ", Remaining);
    
    -obtained(Resource, Current);
    +obtained(Resource, 0);
    !finish_round.

+!denied_quota(Resource, Amount, Required)[source(planner)] <-
    .println(
        "RESOURCE DENIED: ", Resource,
        ". Contribution: ", Amount,
        ". Required contribution: ", Required
    );
    -denied_quota(Resource, Amount, Required);
    //.send(planner, achieve, contribute(Resource, Missing)).
    !finish_round.

+!unknown_resource(Resource)[source(planner)] <-
    -unknown_resource(Resource);
    .println("UNKNOWN RESOURCE: ", Resource).    

+!contribution_recorded(Resource, Added, Total)[source(planner)]
<-
    .println(
        "CONTRIBUTION ACCEPTED FOR: ", Resource,
        ". Added: ", Added,
        ". Total contribution: ", Total,
        ". Retrying request..."
    );
    -contribution_recorded(Resource, Added, Total);
    !satisfy_need(Resource).
    //.send(planner, achieve, obtain(Resource)).   
     