// planner 
// initial beliefs
stock(resource, 3).
min_stock(resource, 1).
// plans
@grant_resource[atomic]
+!obtain(Resource)[source(Requester)]
    : stock(Resource, Quantity) 
    & min_stock(Resource, Minimum) 
    & Quantity > Minimum 
<-
    Remaining = Quantity - 1;
    -stock(Resource, Quantity);
    +stock(Resource, Remaining); 

    .println("REQUEST GRANTED TO: ", Requester, "RESOURCE: ", Resource);

    .send(Requester, tell, granted(Resource, Remaining)).


@deny_resource[atomic]
+!obtain(Resource)[source(Requester)]
    : stock(Resource, Quantity)
    & min_stock(Resource, Minimum)
    & Quantity <= Minimum 
<- 
    .println("REQUEST DENIED TO: ", Requester, "RESOURCE: ", Resource);

    .send(Requester, tell, denied(Resource, Remaining)).



@unknown_resource[atomic]
+!obtain(Resource)[source(Requester)]
    : not stock(Resource, _)
<-
    .println("UNKNOWN RESOURCE REQUESTED: ", Resource);

    .send(Requester, tell, unknown_resource(Resource)).    