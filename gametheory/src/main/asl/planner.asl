// planner 
// initial beliefs

round(1).
stock(resource, 3).
min_stock(resource, 1).

allocated(agent, resource, 0).
contribution_quota(agent, 1).
contribution(agent, 0).
//starting goals

// plans
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

    .send(Requester, tell, unknown_resource(Resource)).  

+!check_contribution(Requester, Resource)
    : contribution(Requester, Amount)
    & contribution_quota(Requester, Required)
    & Amount < Required
<-
    .println("REQUEST DENIED TO ", Requester, ",CONTRIBUTION: ", Amount, ",QUOTA: ", Required);

    .send(Requester, tell, denied_quota(Resource, Amount, Required)).


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

    .send(Requester, tell, denied(Resource, Quantity)).



@grant_resource[atomic]
+!check_stock(Requester, Resource)
    : stock(Resource, Quantity)
    & min_stock(Resource, Minimum)
    & Quantity > Minimum
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

    .send(Requester,tell,granted(Resource, Remaining, NewOwned)).

@record_contribution[atomic]
+!contribute(Resource, Added)[source(Requester)]
    : stock(Resource, _)
    & contribution(Requester, Current)
    & Added > 0
<- 
    Updated = Current + Added; 
    -contribution(Requester, Current);
    +contribution(Requester, Updated);

    .println("CONTRIBUTION RECORDED FROM: ", Requester, "RESOURCE: ", Resource, "ADDED: ", Added, "TOTAL: ", Updated);

    .send(Requester, tell, contribution_recorded(Resource, Added, Updated)).

+!contribute(Resource, Added)[source(Requester)]
    : not stock(Resource, _)
<-
    .println(
        "CONTRIBUTION REJECTED FROM: ", Requester,
        " UNKNOWN RESOURCE: ", Resource
    );

    .send(Requester, tell, unknown_resource(Resource)).    

@release_resource[atomic]
+!release(Resource)[source(Requester)]
    : stock(Resource, Quantity)
      & allocated(Requester, Resource, Owned)
      & Owned > 0
<-
    NewStock = Quantity + 1;
    NewOwned = Owned - 1;

    -stock(Resource, Quantity);
    +stock(Resource, NewStock);

    .println(
        "RESOURCE RELEASED BY: ", Requester,
        " RESOURCE: ", Resource, 
        " OWNED: ", NewOwned, 
        " AVAILABLE STOCK: ", NewStock 
    );

    .send(Requester, tell, released(Resource, NewStock, NewOwned)).

+!release(Resource)[source(Requester)]
    : allocated(Requester, Resource, 0)
<-
    .println(
        "RELEASE DENIED TO: ", Requester,
        ". NO ALLOCATED RESOURCE: ", Resource
    );

    .send(Requester, tell, release_denied(Resource)).    

  