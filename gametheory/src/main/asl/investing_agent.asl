//beliefs
round(1).   
endowment(10).

current_strategy(total_return_1).
last_bid(0).
last_total_return(0).


last_market1_return(0).
last_market2_return(0).

last_group_total(0). 
last_group_average(0).

market1_return(5).
cpr_a(23).
cpr_b(0.25).

total_return_direction(1). // can be +- of direction
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

+start_round(Round, Seed)[source(Planner)]
<- 
    -current_round(_);
    +current_round(Round);

    -planner_name(_);
    +planner_name(Planner);

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

    +strategy_pool([S1,S2,S3,S4]);

    +current_strategy(S1);

    +strategies_picked;

    .println("STRATEGY POOL: ", [S1, S2, S3, S4], "CURRENT: ", S1, " SEED: ", AgentSeed).    

+! pick_random_strategies(Seed)
    : strategies_picked 
<- 
    true.
    
+!generate_strategy_bids(_)
<- 
    for(strategy_score(Strategy, _, _)) {
        !generate_strategy_bid(Strategy);
    }.

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, total_return, Increment, Decrement)
    & last_bid(LastBid)
    & total_return_direction(Direction)
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
    : strategy_rule(Strategy, unit_return, Increment, Decrement)
    & last_bid(LastBid)
    & endowment(Max)
    & last_market1_return(M1Return)
    & last_market2_return(M2Return)
    & LastBid > 0
    & LastBid < Max
<-
    M1Tokens = Max - LastBid;

    M1UnitReturn = M1Return / M1Tokens;
    M2UnitReturn = M2Return / LastBid;

    !generate_unit_direction(Strategy,LastBid,M1UnitReturn,M2UnitReturn,Increment,Decrement,Max).

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, unit_return, Increment, _)
    & Increment \== all
    & last_bid(0)
    & endowment(Max)
<-
    Bid = math.min(Max, Increment);

    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Bid).


+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, unit_return, _, Decrement)
    & last_bid(LastBid)
    & endowment(LastBid)
<-
    Bid = math.max(0, LastBid - Decrement);

    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Bid).

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, unit_return, all, _)
    & last_bid(0)
    & endowment(Max)
<-
    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Max).

+!generate_unit_direction(Strategy, LastBid, M1Unit, M2Unit, Increment, _, Max)
    : M2Unit > M1Unit
    & Increment \== all
<-
    Bid = math.min(Max, LastBid + Increment);

    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Bid).

+!generate_unit_direction(Strategy, _, M1Unit, M2Unit, all, _, Max)
    : M2Unit > M1Unit
<-
    -candidate_bid(Strategy, _);
    +candidate_bid(Strategy, Max).

+!generate_unit_direction(Strategy, LastBid, M1Unit, M2Unit, _, Decrement, _)
    : M1Unit >= M2Unit
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


// +!generate_total_return_bid(_)
//     : last_bid(LastBid)
//     & total_return_direction(Dir)
//     & endowment(Max)
// <-
//     NewBid = LastBid + Dir;

//     Bid = math.max(0, math.min(Max, NewBid));
    
//     -candidate_bid(total_return_1, _);
//     +candidate_bid(total_return_1, Bid).


// +!generate_unit_return_bid(_)
//     : last_bid(LastBid)
//     & endowment(Max)
//     & last_market1_return(M1Return)
//     & last_market2_return(M2Return)
//     & LastBid > 0 
//     & LastBid < Max
// <-  
//     M1Tokens = Max - LastBid; 
//     M1UnitReturn = M1Return / M1Tokens; 
//     M2UnitReturn = M2Return / LastBid;

//     !unit_return_choice(LastBid, M1UnitReturn, M2UnitReturn).


// +!unit_return_choice(LastBid, M1UnitReturn, M2UnitReturn)
//     : M2UnitReturn > M1UnitReturn 
//     & endowment(Max)
// <- 
//     Bid = math.min(Max, LastBid + 1);
//     -candidate_bid(unit_return_1, _);
//     +candidate_bid(unit_return_1, Bid).

// +!unit_return_choice(LastBid, M1UnitReturn, M2UnitReturn)
//     : M1UnitReturn >= M2UnitReturn
// <-
//     Bid = math.max(0, LastBid - 1);

//     -candidate_bid(unit_return_1, _);
//     +candidate_bid(unit_return_1, Bid).

// +!generate_unit_return_bid(_)
//     : last_bid(0)
// <- 
//     -candidate_bid(unit_return_1, _);
//     +candidate_bid(unit_return_1, 1).

// +!generate_unit_return_bid(_)
//     : last_bid(LastBid)
//     & endowment(LastBid)  // check if endowment eq lastbid?
// <-  
//     Bid = LastBid - 1;

//     -candidate_bid(unit_return_1, _);
//     +candidate_bid(unit_return_1, Bid).

// +!generate_group_avg_bid(_)
//     : endowment(Max)
//     & last_group_average(Avg)
// <-
//     Bid = math.max(0, math.min(Max, math.floor(Avg)));

//     -candidate_bid(group_average, _);
//     +candidate_bid(group_average, Bid).

// +!generate_group_avg_plus_1_bid(_)
//     : last_group_average(Avg)
//     & endowment(Max)
// <-        

//     Bid = math.max(0, math.min(Max, math.floor(Avg) + 1));

//     -candidate_bid(group_average_plus1, _);
//     +candidate_bid(group_average_plus1, Bid).

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

    !select_best_strategy;

    .send(Planner, tell, round_finished(Round)).

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

    -last_market1_return(_);
    +last_market1_return(Market1);

    -last_market2_return(_);
    +last_market2_return(Market2);

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
<-
    CounterTotal = GroupTotal - ActualBid + AlternativeBid;

    CounterMarket1 = W * (E - AlternativeBid);

    CounterMarket2 = AlternativeBid * (CprA - CprB * CounterTotal);

    CounterPayoff = CounterMarket1 + CounterMarket2;

    NewSum = Sum + CounterPayoff;
    NewN = N + 1;

    .my_name(Me);
    -strategy_score(Strategy, Sum, N);
    +strategy_score(Strategy, NewSum, NewN);

    results.append(
    "results/strategies.csv", Round, Me, Strategy, AlternativeBid, CounterPayoff, NewSum, NewN);

    .printf(
        "ROUND %.0f EVALUATED %s BID=%.0f PAYOFF=%.2f\n",
        Round,
        Strategy,
        AlternativeBid,
        CounterPayoff
    ).

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

+!compare_strategy(Strategy, Avg, _, BestAvg, Rest)
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
// +!choose_max_strategy(S1, A1, S2, A2, S3, A3, S4, A4)
//     : A1 >= A2 & A1 >= A3 & A1 >= A4
// <-
//     -current_strategy(_);
//     +current_strategy(S1);
//     .println("SELECTED STRATEGY: ", S1, " AVG RETURN: ", A1).

// +!choose_max_strategy(S1, A1, S2, A2, S3, A3, S4, A4)
//     : A2 > A1 & A2 >= A3 & A2 >= A4
// <-
//     -current_strategy(_);
//     +current_strategy(S2);
//     .println("SELECTED STRATEGY: ", S2, " AVG RETURN: ", A2).

// +!choose_max_strategy(S1, A1, S2, A2, S3, A3, S4, A4)
//     : A3 > A1 & A3 > A2 & A3 >= A4
// <-
//     -current_strategy(_);
//     +current_strategy(S3);
//     .println("SELECTED STRATEGY: ", S3, " AVG RETURN: ", A3).

// +!choose_max_strategy(S1, A1, S2, A2, S3, A3, S4, A4)
//     : A4 > A1 & A4 > A2 & A4 > A3
// <-
//     -current_strategy(_);
//     +current_strategy(S4);
//     .println("SELECTED STRATEGY: ", S4, " AVG RETURN: ", A4).



