!start. 

+!start <-
    .println("Requesting a single resource from the start...");
    .send(planner, achieve, obtain(resource)).

+granted(Resource, Remaining)[source(planner)] <- 
    .println("RESOURCE GRANTED: ", Resource, ". Remaining stock: ", Remaining).

+denied(Resource, Remaining)[source(planner)] <- 
    .println("RESOURCE DENIED: ", Resource, ". Available stock: ", Remaining).

+unknown_resource(Resource)[source(planner)] <-
    .println("UNKNOWN RESOURCE: ", Resource).    