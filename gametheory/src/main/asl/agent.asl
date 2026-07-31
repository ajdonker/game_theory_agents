need(resource, 3).
// contribution_quota(resource, 1).
!start. 
// !keep_resource_in_check as the starting goal then request as plan

// is there a point in making trying to req a resource a test goal 
+!start <-
    .println("Requesting a single resource from the start...");
    .send(planner, achieve, obtain(resource)).

+granted(Resource, Remaining)[source(planner)] <- 
    .println("RESOURCE GRANTED: ", Resource, ". Remaining stock: ", Remaining).

+denied(Resource, Remaining)[source(planner)] <- 
    .println("RESOURCE DENIED: ", Resource, ". Available stock: ", Remaining).

+denied_quota(Resource, Amount, Required)[source(planner)] <-
    .println(
        "RESOURCE DENIED: ", Resource,
        ". Contribution: ", Amount,
        ". Required contribution: ", Required
    ).
    
+unknown_resource(Resource)[source(planner)] <-
    .println("UNKNOWN RESOURCE: ", Resource).    