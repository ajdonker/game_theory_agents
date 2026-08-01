need(resource, 2).
obtained(resource, 0).
// contribution_quota(resource, 1).
!start. 
// !keep_resource_in_check as the starting goal then request as plan

// is there a point in making trying to req a resource a test goal 
+!start <-
    .println("Starting resource acquisition...");
    //.send(planner, achieve, obtain(resource)).
    !satisfy_need(resource).

+!satisfy_need(Resource) 
    :need(Resource, Required)
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
        "RESOURCE NEED SATISFIED: ", Resource, 
        ". Total obtained: ", Current    
    );

    .send(planner, achieve, release(Resource)).    


+release_denied(Resource)[source(planner)]
<-
    .println(
        "CANNOT RELEASE RESOURCE: ", Resource,
        ". Agent owns none."
    ).

+released(Resource, AvailableStock, RemainingOwned)[source(planner)]
<-
    -obtained(Resource, _);
    +obtained(Resource, RemainingOwned);

    .println(
        "RESOURCE RELEASE CONFIRMED: ", Resource,
        ". Remaining owned: ", RemainingOwned,
        ". Available stock: ", AvailableStock
    ).

+granted(Resource, Remaining, TotalOwned)[source(planner)]
<-
    -obtained(Resource, _);
    +obtained(Resource, TotalOwned);

    .println(
        "RESOURCE GRANTED: ", Resource,
        ". Total owned: ", TotalOwned,
        ". Remaining stock: ", Remaining
    );

    !satisfy_need(Resource).+granted(Resource, Remaining)[source(planner)] <- 
    .println("RESOURCE GRANTED: ", Resource, ". Remaining stock: ", Remaining).

+denied(Resource, Remaining)[source(planner)] <- 
    .println("RESOURCE DENIED: ", Resource, ". Available stock: ", Remaining).

+denied_quota(Resource, Amount, Required)[source(planner)] <-
    Missing = Required - Amount;
    .println(
        "RESOURCE DENIED: ", Resource,
        ". Contribution: ", Amount,
        ". Required contribution: ", Required,
        ". Contributing: ", Missing
    );
    .send(planner, achieve, contribute(Resource, Missing)).
    
+unknown_resource(Resource)[source(planner)] <-
    .println("UNKNOWN RESOURCE: ", Resource).    

+contribution_recorded(Resource, Added, Total)[source(planner)]
<-
    .println(
        "CONTRIBUTION ACCEPTED FOR: ", Resource,
        ". Added: ", Added,
        ". Total contribution: ", Total,
        ". Retrying request..."
    );

    .send(planner, achieve, obtain(Resource)).    