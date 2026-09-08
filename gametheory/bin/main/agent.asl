need(resource, 2).
obtained(resource, 0).
strategy(cooperating).
current_round(0).
// contribution_quota(resource, 1).
//!start. 
// !keep_resource_in_check as the starting goal then request as plan

// is there a point in making trying to req a resource a test goal 
// +!start <-
//     .println("Starting resource acquisition...");
//     //.send(planner, achieve, obtain(resource)).
//     !satisfy_need(resource).

+start_round(Round)[source(planner)]
<- 
    -current_round(_);
    +current_round(Round);
    .println("Round ", Round, " Received");
    !choose_contribution(Round).


+!choose_contribution(Round)
    : strategy(cooperating)
<-
    .println("Round ", Round, ": strategy = cooperating. Contributing 1.");
    .send(planner, achieve, contribute(resource, 1)).


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

    !release_resource(Resource).

+! release_resource(Resource)
    : obtained(Resource, Current)
    & Current > 0
<- 
    .send(planner, achieve, release(Resource)).


+! release_resource(Resource)
    : obtained(Resource, 0)
<-
    !finish_round.


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

+!released(Resource, AvailableStock, RemainingOwned)[source(planner)]
<-
    -obtained(Resource, _);
    +obtained(Resource, RemainingOwned);

    .println(
        "RESOURCE RELEASE CONFIRMED: ", Resource,
        ". Remaining owned: ", RemainingOwned,
        ". Available stock: ", AvailableStock
    );
    -released(Resource, AvailableStock, RemainingOwned);
    !release_resource(Resource).

// next handler can be removed 
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
    
+!denied(Resource, Remaining)[source(planner)] <- 
    -denied(Resource, Remaining);
    .println("RESOURCE DENIED: ", Resource, ". Available stock: ", Remaining).

+!denied_quota(Resource, Amount, Required)[source(planner)] <-
    Missing = Required - Amount;
    .println(
        "RESOURCE DENIED: ", Resource,
        ". Contribution: ", Amount,
        ". Required contribution: ", Required,
        ". Contributing: ", Missing
    );
    -denied_quota(Resource, Amount, Required);
    .send(planner, achieve, contribute(Resource, Missing)).
    
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
     