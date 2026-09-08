// planner 
// initial beliefs

round(1).
max_rounds(5).
active_agent(agent1).
active_agent(agent2).
active_agent(agent3).
active_agent(agent4).
active_agent(agent5).

stock(resource, 15).
min_stock(resource, 1).

acted(agent1, 0).
acted(agent2, 0).
acted(agent3, 0).
acted(agent4, 0).
acted(agent5, 0).
allocated(agent1, resource, 0).
allocated(agent2, resource, 0).
allocated(agent3, resource, 0).
allocated(agent4, resource, 0).
allocated(agent5, resource, 0).

contribution_quota(agent1, 1).
contribution_quota(agent2, 1).
contribution_quota(agent3, 1).
contribution_quota(agent4, 1).
contribution_quota(agent5, 1).


contribution(agent1, 0).
contribution(agent2, 0).
contribution(agent3, 0).
contribution(agent4, 0).
contribution(agent5, 0).

//starting goals
!start.
// plans
+!start <- 
    .println("STARTING SIM");
    !start_round.


+!start_round
    : round(Round)
<-
    for (active_agent(A)) {
        -contribution(A, _);
        +contribution(A, 0);

        -acted(A, _);
        +acted(A, _);
    }
    .println("");
    .println("===============");
    .println("STARTING ROUND: ", Round);
    .println("===============");

    .broadcast(tell, start_round(Round)).

@obtain[atomic]
+! obtain(Resource)[source(Requester)]
    :stock(Resource, _)
<- 
    .println("REQUEST RECEIVED FROM: ", Requester,
             "RESOURCE: ", Resource);
             
    !check_contribution(Requester, Resource).

@unknown_resource[atomic]
+!obtain(Resource)[source(Requester)]
    : not stock(Resource, _)
<-
    .println("UNKNOWN RESOURCE REQUESTED: ", Resource);

    .send(Requester, achieve, unknown_resource(Resource)).  

+!check_contribution(Requester, Resource)
    : contribution(Requester, Amount)
    & contribution_quota(Requester, Required)
    & Amount < Required
<-
    .println("REQUEST DENIED TO ", Requester, ",CONTRIBUTION: ", Amount, ",QUOTA: ", Required);

    .send(Requester, achieve, denied_quota(Resource, Amount, Required)).


+!check_contribution(Requester, Resource)
    : contribution(Requester, Amount)
    & contribution_quota(Requester, Required)
    & Amount >= Required
<-
    !check_stock(Requester, Resource).


@deny_resource[atomic]
+!check_stock(Requester, Resource)
    : stock(Resource, Quantity)
    & min_stock(Resource, Minimum)
    & Quantity <= Minimum 
<- 
    .println("REQUEST DENIED TO: ", Requester, "RESOURCE: ", Resource);

    .send(Requester, achieve, denied(Resource, Quantity)).



@grant_resource[atomic]
+!check_stock(Requester, Resource)
    : stock(Resource, Quantity)
    & min_stock(Resource, Minimum)
    & Quantity > Minimum
    & allocated(Requester, Resource, Owned)
<-
    !allocate_resource(Requester, Resource).

+!allocate_resource(Requester, Resource)
    :stock(Resource, Quantity)
    & allocated(Requester, Resource, Owned)
<- 
    Remaining = Quantity - 1;
    NewOwned = Owned + 1;

    -stock(Resource, Quantity);
    +stock(Resource, Remaining);

    -allocated(Requester, Resource, Owned);
    +allocated(Requester, Resource, NewOwned);

    .println(
        "REQUEST GRANTED TO: ", Requester,
        " RESOURCE: ", Resource,
        " OWNED: ", NewOwned,
        " REMAINING STOCK: ", Remaining
    );

    !notify_granted(Requester, Resource, Remaining, NewOwned).

+!notify_granted(Requester, Resource, Remaining, NewOwned)
<- 
    .send(Requester, achieve, granted(Resource, Remaining, NewOwned)).    

@record_contribution[atomic]
+!contribute(Resource, Added)[source(Requester)]
    : stock(Resource, _)
    & contribution(Requester, Current)
    & Added > 0
<- 

    !record_contribution(Requester, Resource, Added, Current).

+!record_contribution(Requester, Resource, Added, Current)
<- 
    Updated = Current + Added;

    -contribution(Requester, Current);
    +contribution(Requester, Updated);

    !notify_contribution_recorded(Requester, Resource, Added, Updated).

+!notify_contribution_recorded(Requester, Resource, Added, Updated)
<- 
    .send(Requester, achieve, contribution_recorded(Resource, Added, Updated)).

+!contribute(Resource, Added)[source(Requester)]
    : not stock(Resource, _)
<-
    .println(
        "CONTRIBUTION REJECTED FROM: ", Requester,
        " UNKNOWN RESOURCE: ", Resource
    );

    .send(Requester, achieve, unknown_resource(Resource)).    

@release_resource[atomic]
+!release(Resource)[source(Requester)]
    : stock(Resource, Quantity)
      & allocated(Requester, Resource, Owned)
      & Owned > 0
<-
    !deallocate_resource(Requester, Resource).


+!deallocate_resource(Requester, Resource)
    :stock(Resource, Quantity)
    & allocated(Requester, Resource, Owned)
    & Owned > 0
<- 
    
    NewStock = Quantity + 1;
    NewOwned = Owned - 1;

    -stock(Resource, Quantity);
    +stock(Resource, NewStock);

    -allocated(Requester, Resource, Owned);
    +allocated(Requester, Resource, NewOwned);

    !notify_released(Requester, Resource, NewStock, NewOwned).

+!notify_released(Requester, Resource, NewStock, NewOwned)
<-
    .send(Requester, achieve, released(Resource, NewStock, NewOwned)).

+!release(Resource)[source(Requester)]
    : allocated(Requester, Resource, 0)
<-
    .println(
        "RELEASE DENIED TO: ", Requester,
        ". NO ALLOCATED RESOURCE: ", Resource
    );

    .send(Requester, achieve, release_denied(Resource)).    


+round_finished(Round)[source(Requester)]
    : round(Round)
    & active_agent(Requester)
    & acted(Requester, 0)
<-
    -acted(Requester, 0);
    +acted(Requester, 1);

    .println(
        "AGENT ", Requester,
        " FINISHED ROUND ", Round
    );

    !check_round_complete.


+!check_round_complete
    : acted(agent1, 1)
    & acted(agent2, 1)
    & acted(agent3, 1)
    & acted(agent4, 1)
    & acted(agent5, 1)
<-
    !advance_round.

+!check_round_complete
    : not (
        acted(agent1, 1)
        & acted(agent2, 1)
        & acted(agent3, 1)
        & acted(agent4, 1)
        & acted(agent5, 1)
    )
<-
    true.

+!advance_round
    : round(Round)
    & max_rounds(Max)
    & Round < Max 
<- 
    NextRound = Round + 1;

    -round(Round);
    +round(NextRound);

    !start_round.

+!advance_round
    : round(Round)
    & max_rounds(Max)
    & Round >= Max
<-
    .println("");
    .println("========================");
    .println("SIMULATION FINISHED");
    .println("ROUNDS COMPLETED: ", Round);
    .println("========================").         