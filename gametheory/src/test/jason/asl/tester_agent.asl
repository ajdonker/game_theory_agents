{ include("$jasonJar/test/jason/inc/tester_agent.asl") }
{ include("agent.asl") }

@[test]
+!test_initial_state
<-
    ?need(resource, Need);
    !assert_equals(2, Need);

    ?obtained(resource, Owned);
    !assert_equals(0, Owned).