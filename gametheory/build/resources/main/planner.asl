// planner 
// initial beliefs

round(1).
stock(resource, 3).
min_stock(resource, 1).

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
<-
    Remaining = Quantity - 1;
    -stock(Resource, Quantity);
    +stock(Resource, Remaining); 

    .println("REQUEST GRANTED TO: ", Requester, "RESOURCE: ", Resource);

    .send(Requester, tell, granted(Resource, Remaining)).


  