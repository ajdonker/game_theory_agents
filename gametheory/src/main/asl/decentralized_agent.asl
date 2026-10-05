//beliefs
round(1).   
endowment(10).

last_bid(0).
last_total_return(0).



last_market1_return(0).
last_market2_return(0).

last_group_total(0). 
last_group_average(0).

market1_return(5).
cpr_a(23).
cpr_b(0.25).

//total_return_direction(1). // replaced with strategy_direction belief that is modified if incr/decr return
// avg scores for each strategy even not played
// strat, type, incr, decr 
strategy_rule(total_return_1, total_return, 1, 1).
strategy_rule(total_return_2, total_return, 2, 2).
strategy_rule(total_return_3, total_return, 3, 3).
strategy_rule(total_return_4, total_return, 4, 4).
strategy_rule(total_return_all_dec3, total_return, all, 3).
strategy_rule(total_return_all_dec5, total_return, all, 5).

strategy_rule(unit_return_1, unit_return, 1, 1).
strategy_rule(unit_return_2, unit_return, 2, 2).
strategy_rule(unit_return_3, unit_return, 3, 3).
strategy_rule(unit_return_4, unit_return, 4, 4).
strategy_rule(unit_return_all_dec3, unit_return, all, 3).
strategy_rule(unit_return_all_dec5, unit_return, all, 5).

strategy_rule(group_average_0, group_average, 0).
strategy_rule(group_average_1, group_average, 1).
strategy_rule(group_average_2, group_average, 2).
strategy_rule(group_average_3, group_average, 3).

// initial round 0 scores 
// strategy_score(total_return_1, 0, 0).
// strategy_score(unit_return_1, 0, 0).
// strategy_score(group_average_0, 0, 0).
// strategy_score(group_average_plus1, 0, 0).
all_strategies([total_return_1, total_return_2, total_return_3, total_return_4,
    total_return_all_dec3, total_return_all_dec5,
    unit_return_1, unit_return_2, unit_return_3, unit_return_4,
    unit_return_all_dec3, unit_return_all_dec5,
    group_average_0, group_average_1, group_average_2, group_average_3]).

agent_index(agent1, 1).
agent_index(agent2, 2).
agent_index(agent3, 3).
agent_index(agent4, 4).
agent_index(agent5, 5).
agent_index(agent6, 6).
agent_index(agent7, 7).
agent_index(agent8, 8).

+start_round(RunId, Round, Seed)[source(Planner)]
<- 
    -run_id(_);
    +run_id(RunId);
    
    -current_round(_);
    +current_round(Round);

    -planner_name(_);
    +planner_name(Planner);

    -planner_seed(_);
    +planner_seed(Seed);

    !pick_random_strategies(Seed);

    !generate_strategy_bids(Round);
    !play_current_strategy(Round).

//plans
+! pick_random_strategies(Seed)
    : not strategies_picked
    & all_strategies(All)
<- 
    .my_name(Me);
    ?agent_index(Me, Index);

    AgentSeed = Seed * 100 + Index;
    .set_random_seed(AgentSeed);

    .shuffle(All, Shuffled);

    .nth(0, Shuffled, S1);
    .nth(1, Shuffled, S2);
    .nth(2, Shuffled, S3);
    .nth(3, Shuffled, S4);

    +strategy_score(S1, 0, 0);
    +strategy_score(S2, 0, 0);
    +strategy_score(S3, 0, 0);
    +strategy_score(S4, 0, 0);

    !init_strategy_state(S1);
    !init_strategy_state(S2);
    !init_strategy_state(S3);
    !init_strategy_state(S4);

    +strategy_pool([S1,S2,S3,S4]);

    +current_strategy(S1);

    +strategies_picked;

    .println("STRATEGY POOL: ", [S1, S2, S3, S4], "CURRENT: ", S1, " SEED: ", AgentSeed).    

+! pick_random_strategies(Seed)
    : strategies_picked 
<- 
    true.

+! init_strategy_state(Strategy)
    : strategy_rule(Strategy, total_return, _, _)
<-  
    +strategy_last_bid(Strategy, 0);
    +strategy_direction(Strategy, 1);
    +strategy_last_payoff(Strategy, 0);
    +strategy_has_payoff(Strategy, false).

+! init_strategy_state(Strategy)
    : strategy_rule(Strategy, unit_return, _, _)
<- 
    +strategy_last_bid(Strategy, 0);
    +strategy_last_market1_return(Strategy, 0);
    +strategy_last_market2_return(Strategy, 0).

+!init_strategy_state(Strategy)
    : strategy_rule(Strategy, group_average, _)
<-
    true.

+!generate_strategy_bids(_)
<- 
    for(strategy_score(Strategy, _, _)) {
        !generate_strategy_bid(Strategy);
    }.

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, total_return, Increment, Decrement)
    //& last_bid(LastBid)
    & strategy_last_bid(Strategy, LastBid)
    // & total_return_direction(Direction)
    & strategy_direction(Strategy, Direction)
    & endowment(Max)
<-
    !generate_directional_bid(Strategy, LastBid, Direction, Increment, Decrement, Max).

+! generate_directional_bid(Strategy, LastBid, 1, Increment, _, Max)
    : Increment \== all 
<- 
    Bid = math.min(Max, LastBid + Increment);

    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Bid).    

+!generate_directional_bid(Strategy, _, 1, all, _, Max)
<-
    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Max).

+!generate_directional_bid(Strategy, LastBid, -1, _,Decrement,_)
<-
    Bid = math.max(0, LastBid - Decrement);

    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Bid).

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, unit_return, Increment, _)
    & Increment \== all
    & strategy_last_bid(Strategy, LastBid)
    & strategy_last_market1_return(Strategy, M1Return)
    & strategy_last_market2_return(Strategy, M2Return)
    & endowment(Max)
    & LastBid > 0
    & LastBid < Max
    & M2Return / LastBid > M1Return / (Max - LastBid)
<-
    Bid = math.min(Max, LastBid + Increment);

    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Bid).

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, unit_return, all, _)
    & strategy_last_bid(Strategy, LastBid)
    & strategy_last_market1_return(Strategy, M1Return)
    & strategy_last_market2_return(Strategy, M2Return)
    & endowment(Max)
    & LastBid > 0
    & LastBid < Max
    & M2Return / LastBid > M1Return / (Max - LastBid)
<-
    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Max).

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, unit_return, _, Decrement)
    & strategy_last_bid(Strategy, LastBid)
    & strategy_last_market1_return(Strategy, M1Return)
    & strategy_last_market2_return(Strategy, M2Return)
    & endowment(Max)
    & LastBid > 0
    & LastBid < Max
    & M1Return / (Max - LastBid) >= M2Return / LastBid
<-
    Bid = math.max(0, LastBid - Decrement);

    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Bid).

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, unit_return, Increment, _)
    & Increment \== all
    & strategy_last_bid(Strategy, 0)
    & endowment(Max)
<-
    Bid = math.min(Max, Increment);

    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Bid).

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, unit_return, all, _)
    & strategy_last_bid(Strategy, 0)
    & endowment(Max)
<-
    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Max).        

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, unit_return, _, Decrement)
    & strategy_last_bid(Strategy, LastBid)
    & endowment(Max)
    & LastBid == Max
<-
    Bid = math.max(0, LastBid - Decrement);

    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Bid).

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, group_average, Offset)
    & last_group_average(Avg)
    & endowment(Max)
<-
    Bid = math.max(0, math.min(Max, math.floor(Avg) + Offset));

    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Bid).

+!generate_strategy_bid(comm(Bid))
<-
    -candidate_bid(comm(_), _);
    +candidate_bid(comm(Bid), Bid).

+!play_current_strategy(Round)
    : current_strategy(Strategy)
    & candidate_bid(Strategy, Bid)
    & planner_name(Planner)
<-
    .println(
        "ROUND ", Round,
        " STRATEGY: ", Strategy,
        " BID: ", Bid
    );

    .send(
        Planner,
        achieve,
        submit_bid(Round, Bid, Strategy)
    ).

+!round_result(
    Round,
    ActualBid,
    GroupTotal,
    GroupAverage,
    Market1,
    Market2,
    ActualPayoff
)[source(Planner)]
<-
    .println(
        "ROUND ", Round,
        " PAYOFF: ", ActualPayoff,
        " GROUP INVESTMENT: ", GroupTotal
    );

    !evaluate_strategies(
        Round,
        ActualBid,
        GroupTotal
    );

    !update_history(
        ActualBid,
        GroupTotal,
        GroupAverage,
        Market1,
        Market2,
        ActualPayoff
    );

    //!select_best_strategy;
    // !maybe_select_strategy(Round);

    // .send(Planner, tell, round_finished(Round)).

    !after_round(Round, ActualBid, GroupTotal).

+!after_round(Round, ActualBid, GroupTotal)
    : Round mod 5 == 0
<-
    !start_comm(Round, ActualBid, GroupTotal).

+!after_round(Round, _, _)
    : Round mod 5 \== 0
    & planner_name(Planner)
<-
    !maybe_select_strategy(Round);

    .send(Planner, tell, round_finished(Round)).

+!start_comm(Round, ActualBid, GroupTotal)
<-
    !select_best_strategy;

    ?current_strategy(BestStrategy);

    ?candidate_bid(BestStrategy, BestBid);

    +comm_context(Round, ActualBid, GroupTotal);

    .my_name(Me);

    .println(
        "COMM ROUND ", Round,
        " | ", Me,
        " SUGGESTS ", BestBid,
        " FROM ", BestStrategy
    );   

    .broadcast(tell, comm_suggestion(Round, BestBid));

    !check_comm_ready(Round).

+comm_suggestion(Round, Bid)[source(Sender)]
    : not received_comm_bid(Round, Sender, _)
<-
    +received_comm_bid(Round, Sender, Bid);

    !check_comm_ready(Round).

+!check_comm_ready(Round)
    : comm_context(Round, _, _)
    & not comm_done(Round)
<-
    .count(received_comm_bid(Round, _, _), Count);

    !check_comm_count(Round, Count).

+!check_comm_ready(_)
<-
    true.

+!check_comm_count(Round, 7)
    : comm_context(Round, ActualBid, GroupTotal)
    & not comm_done(Round)
<-
    +comm_done(Round);

    !evaluate_comm_bids(Round, ActualBid, GroupTotal).

+!check_comm_count(_, Count)
    : Count < 7
<-
    true.

+!evaluate_comm_bids(Round, ActualBid, GroupTotal)
<-
    for(received_comm_bid(Round, Sender, Bid)) {
        !evaluate_comm_bid(Round, Sender, Bid, ActualBid, GroupTotal);
    };
    
    ?best_comm_bid(Round, BestBid, BestPayoff);

    .println(
        "COMM ROUND ", Round,
        " | SELECTED BID ", BestBid,
        " | EXPECTED PAYOFF ", BestPayoff
    );

    !install_comm_strategy(BestBid);

    ?planner_name(Planner);

    .send(Planner, tell, round_finished(Round)).

+!evaluate_comm_bid(Round, Sender, Bid, ActualBid, GroupTotal)
    : endowment(E)
    & market1_return(W)
    & cpr_a(CprA)
    & cpr_b(CprB)
<-
    CounterTotal = GroupTotal - ActualBid + Bid;

    CounterMarket1 = W * (E - Bid);

    CounterMarket2 = Bid * (CprA - CprB * CounterTotal);

    CounterPayoff = CounterMarket1 + CounterMarket2;

    .println(
        "COMM EVAL ", Sender,
        " BID ", Bid,
        " PAYOFF ", CounterPayoff
    );

    !consider_comm_bid(Round, Bid, CounterPayoff).

+!consider_comm_bid(Round, Bid, Payoff)
    : not best_comm_bid(Round, _, _)
<-
    +best_comm_bid(Round, Bid, Payoff).

+!consider_comm_bid(Round, Bid, Payoff)
    : best_comm_bid(Round, BestBid, BestPayoff)
    & Payoff > BestPayoff            
<-
    -best_comm_bid(Round, _, _);
    +best_comm_bid(Round, Bid, Payoff).

+!consider_comm_bid(Round, _, Payoff)
    : best_comm_bid(Round, _, BestPayoff)
    & BestPayoff >= Payoff
<-
    true.

+!install_comm_strategy(Bid)
<-
    !remove_old_comm_strategy;
    +strategy_score(comm(Bid), 0, 0);
    +candidate_bid(comm(Bid), Bid);

    //initially adopt as current
    -current_strategy(_);
    +current_strategy(comm(Bid)).

+!remove_old_comm_strategy
    : strategy_score(comm(OldBid), Sum, N)
<-
    -strategy_score(comm(OldBid), Sum, N);
    -candidate_bid(comm(OldBid), _).

+!remove_old_comm_strategy
    : not strategy_score(comm(_), _, _)
<-
    true.

+!update_history(
    ActualBid,
    GroupTotal,
    GroupAverage,
    Market1,
    Market2,
    ActualPayoff
)
<-
    -last_bid(_);
    +last_bid(ActualBid);

    -last_total_return(_);
    +last_total_return(ActualPayoff);

    // -last_market1_return(_);
    // +last_market1_return(Market1);

    // -last_market2_return(_);
    // +last_market2_return(Market2);

    -last_group_total(_);
    +last_group_total(GroupTotal);

    -last_group_average(_);
    +last_group_average(GroupAverage).

+! evaluate_strategies(Round, ActualBid, GroupTotal)
<-
// in the paper this is done in the planner and sent to the agents  
    for(strategy_score(Strategy, _, _)) {
        !evaluate_strategy(Strategy, Round, ActualBid, GroupTotal);
    }.


+!evaluate_strategy(Strategy, Round, ActualBid, GroupTotal)
    : candidate_bid(Strategy, AlternativeBid)
    & endowment(E)
    & market1_return(W)
    & cpr_a(CprA)
    & cpr_b(CprB)
    & strategy_score(Strategy, Sum, N)
    & planner_seed(Seed)
    & run_id(RunId)
<-
    .my_name(Me);

    CounterTotal = GroupTotal - ActualBid + AlternativeBid;

    CounterMarket1 = W * (E - AlternativeBid);

    CounterMarket2 = AlternativeBid * (CprA - CprB * CounterTotal);

    CounterPayoff = CounterMarket1 + CounterMarket2;

    NewSum = Sum + CounterPayoff;
    NewN = N + 1;

    !update_total_return_direction(Strategy, CounterPayoff);

    .my_name(Me);
    -strategy_score(Strategy, Sum, N);
    +strategy_score(Strategy, NewSum, NewN);

    !update_strategy_last_bid(Strategy, AlternativeBid);

    !update_strategy_returns(Strategy, CounterMarket1, CounterMarket2);

    // results.append(
    // "results/strategies.csv", Seed, Round, Me, Strategy, AlternativeBid, CounterPayoff, NewSum, NewN);
    results.append(
    "results/decentralized/strategies.csv",
        RunId, Seed, Round,
        Me, Strategy, AlternativeBid,
        CounterPayoff, NewSum, NewN
    );
    .printf(
        "ROUND %.0f EVALUATED %s BID=%.0f PAYOFF=%.2f\n",
        Round,
        Strategy,
        AlternativeBid,
        CounterPayoff
    ).

+!update_strategy_last_bid(Strategy, Bid)
    : strategy_rule(Strategy, total_return, _, _)
    & strategy_last_bid(Strategy, _)
<-
    -strategy_last_bid(Strategy, _);
    +strategy_last_bid(Strategy, Bid).

+!update_strategy_last_bid(Strategy, Bid)
    : strategy_rule(Strategy, unit_return, _, _)
    & strategy_last_bid(Strategy, _)
<-
    -strategy_last_bid(Strategy, _);
    +strategy_last_bid(Strategy, Bid).

+!update_strategy_last_bid(Strategy, _)
    : strategy_rule(Strategy, group_average, _)
<-
    true.

+!update_strategy_last_bid(comm(_), _)
<-
    true.

+!update_strategy_returns(Strategy, Market1, Market2) // market returns relevant only for unit return strats
    : strategy_rule(Strategy, unit_return, _, _)
<-
    -strategy_last_market1_return(Strategy, _);
    +strategy_last_market1_return(Strategy, Market1);

    -strategy_last_market2_return(Strategy, _);
    +strategy_last_market2_return(Strategy, Market2).

+!update_strategy_returns(Strategy, _, _)
    : strategy_rule(Strategy, total_return, _, _)
<-
    true.

+!update_strategy_returns(Strategy, _, _)
    : strategy_rule(Strategy, group_average, _)
<-
    true.

+!update_strategy_returns(comm(_), _, _)
<-
    true.

+! maybe_select_strategy(Round) 
    : Round mod 3 == 0
<-
    !select_best_strategy.

+! maybe_select_strategy(Round)
    : Round mod 3 \== 0
<- 
    true.

+!select_best_strategy
<- 
    .findall(
        [Strategy, Sum, N],
        strategy_score(Strategy, Sum, N) & N > 0,
        Scores
    );

    !choose_max_strategy(Scores).

+!choose_max_strategy([[Strategy, Sum, N] | Rest])
<-
    Avg = Sum / N;

    !scan_strategies(Rest, Strategy, Avg).

+!scan_strategies(
    [[Strategy, Sum, N] | Rest],
    BestStrategy,
    BestAvg
)
<-
    Avg = Sum / N;

    !compare_strategy(Strategy, Avg, BestStrategy, BestAvg, Rest).


+!compare_strategy(Strategy, Avg, _, BestAvg, Rest)
    : Avg > BestAvg
<-
    !scan_strategies(Rest, Strategy, Avg).

+!compare_strategy(_, Avg, BestStrategy, BestAvg, Rest)
    : BestAvg >= Avg
<-    
    !scan_strategies(Rest, BestStrategy, BestAvg).

+!scan_strategies([], BestStrategy, BestAvg)
<-
    -current_strategy(_);
    +current_strategy(BestStrategy);

    .printf(
        "SELECTED STRATEGY: %s AVG RETURN: %.2f\n",
        BestStrategy,
        BestAvg
    ).
+!update_total_return_direction(Strategy, Payoff)
    : strategy_rule(Strategy, total_return, _, _)
    & strategy_has_payoff(Strategy, false)
<-
    -strategy_last_payoff(Strategy, _);
    +strategy_last_payoff(Strategy, Payoff);

    -strategy_has_payoff(Strategy, false);
    +strategy_has_payoff(Strategy, true).

+!update_total_return_direction(Strategy, Payoff)
    : strategy_rule(Strategy, total_return, _, _)
    & strategy_has_payoff(Strategy, true)
    & strategy_last_payoff(Strategy, Previous)
    & Payoff >= Previous
<-
    -strategy_last_payoff(Strategy, Previous);
    +strategy_last_payoff(Strategy, Payoff).

+!update_total_return_direction(Strategy, Payoff)
    : strategy_rule(Strategy, total_return, _, _)
    & strategy_has_payoff(Strategy, true)
    & strategy_last_payoff(Strategy, Previous)
    & strategy_direction(Strategy, Direction)
    & Payoff < Previous
<-
    NewDirection = Direction * -1;

    -strategy_direction(Strategy, Direction);
    +strategy_direction(Strategy, NewDirection);

    -strategy_last_payoff(Strategy, Previous);
    +strategy_last_payoff(Strategy, Payoff);

    .println(
        "REVERSED ", Strategy,
        " DIRECTION ", Direction,
        " -> ", NewDirection,
        " PAYOFF ", Previous,
        " -> ", Payoff
    ).

+!update_total_return_direction(Strategy, _)
    : not strategy_rule(Strategy, total_return, _, _)
<-
    true.    
