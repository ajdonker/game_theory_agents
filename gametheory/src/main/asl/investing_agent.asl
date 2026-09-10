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
strategy_score(total_return_1, 0, 0).
strategy_score(unit_return_1, 0, 0).
strategy_score(group_average, 0, 0).
strategy_score(group_average_plus1, 0, 0).

+start_round(Round)[source(Planner)]
<- 
    -current_round(_);
    +current_round(Round);

    -planner_name(_);
    +planner_name(Planner);

    !generate_strategy_bids(Round);
    !play_current_strategy(Round).

//plans 
+!generate_strategy_bids(Round)
<- 
    !generate_total_return_bid(Round);
    !generate_unit_return_bid(Round);
    !generate_group_avg_bid(Round);
    !generate_group_avg_plus_1_bid(Round).

+!generate_total_return_bid(_)
    : last_bid(LastBid)
    & total_return_direction(Dir)
    & endowment(Max)
<-
    NewBid = LastBid + Dir;

    Bid = math.max(0, math.min(Max, NewBid));
    
    -candidate_bid(total_return_1, _);
    +candidate_bid(total_return_1, Bid).


+!generate_unit_return_bid(_)
    : last_bid(LastBid)
    & endowment(Max)
    & last_market1_return(M1Return)
    & last_market2_return(M2Return)
    & LastBid > 0 
    & LastBid < Max
<-  
    M1Tokens = Max - LastBid; 
    M1UnitReturn = M1Return / M1Tokens; 
    M2UnitReturn = M2Return / LastBid;

    !unit_return_choice(LastBid, M1UnitReturn, M2UnitReturn).


+!unit_return_choice(LastBid, M1UnitReturn, M2UnitReturn)
    : M2UnitReturn > M1UnitReturn 
    & endowment(Max)
<- 
    Bid = math.min(Max, LastBid + 1);
    -candidate_bid(unit_return_1, _);
    +candidate_bid(unit_return_1, Bid).

+!unit_return_choice(LastBid, M1UnitReturn, M2UnitReturn)
    : M1UnitReturn >= M2UnitReturn
<-
    Bid = math.max(0, LastBid - 1);

    -candidate_bid(unit_return_1, _);
    +candidate_bid(unit_return_1, Bid).

+!generate_unit_return_bid(_)
    : last_bid(0)
<- 
    -candidate_bid(unit_return_1, _);
    +candidate_bid(unit_return_1, 1).

+!generate_unit_return_bid(_)
    : last_bid(LastBid)
    & endowment(LastBid)  // check if endowment eq lastbid?
<-  
    Bid = LastBid - 1;

    -candidate_bid(unit_return_1, _);
    +candidate_bid(unit_return_1, Bid).

+!generate_group_avg_bid(_)
    : endowment(Max)
    & last_group_average(Avg)
<-
    Bid = math.max(0, math.min(Max, math.floor(Avg)));

    -candidate_bid(group_average, _);
    +candidate_bid(group_average, Bid).

+!generate_group_avg_plus_1_bid(_)
    : last_group_average(Avg)
    & endowment(Max)
<-        

    Bid = math.max(0, math.min(Max, math.floor(Avg) + 1));

    -candidate_bid(group_average_plus1, _);
    +candidate_bid(group_average_plus1, Bid).

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
        submit_bid(Round, Bid)
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
    !evaluate_strategy(total_return_1, Round, ActualBid, GroupTotal);
    !evaluate_strategy(unit_return_1, Round, ActualBid, GroupTotal);
    !evaluate_strategy(group_average, Round, ActualBid, GroupTotal);
    !evaluate_strategy(group_average_plus1, Round, ActualBid, GroupTotal).


+!evaluate_strategy(Strategy, Round, ActualBid, GroupTotal)
    : candidate_bid(Strategy, AlternativeBid)
    & endowment(E)
    & market1_return(W)
    & cpr_a(CprA)
    & cpr_b(CprB)
    & strategy_score(Strategy, Sum, N)
<-
    CounterTotal =
        GroupTotal - ActualBid + AlternativeBid;

    CounterMarket1 =
        W * (E - AlternativeBid);

    CounterMarket2 =
        AlternativeBid *
        (CprA - CprB * CounterTotal);

    CounterPayoff =
        CounterMarket1 + CounterMarket2;

    NewSum = Sum + CounterPayoff;
    NewN = N + 1;

    -strategy_score(Strategy, Sum, N);
    +strategy_score(Strategy, NewSum, NewN);

    .printf(
        "ROUND %.0f EVALUATED %s BID=%.0f PAYOFF=%.2f\n",
        Round,
        Strategy,
        AlternativeBid,
        CounterPayoff
    ).

+!select_best_strategy
    : strategy_score(total_return_1, S1, N1)
    & strategy_score(unit_return_1, S2, N2)
    & strategy_score(group_average, S3, N3)
    & strategy_score(group_average_plus1, S4, N4)
    & N1 > 0
    & N2 > 0
    & N3 > 0
    & N4 > 0
<-
    A1 = S1 / N1;
    A2 = S2 / N2;
    A3 = S3 / N3;
    A4 = S4 / N4;

    .printf(
        "AVERAGES: total=%.2f unit=%.2f avg=%.2f avg+1=%.2f\n",
        A1, A2, A3, A4
    );

    !choose_max_strategy(
        total_return_1, A1,
        unit_return_1, A2,
        group_average, A3,
        group_average_plus1, A4
    ).

+!choose_max_strategy(S1, A1, S2, A2, S3, A3, S4, A4)
    : A1 >= A2 & A1 >= A3 & A1 >= A4
<-
    -current_strategy(_);
    +current_strategy(S1);
    .println("SELECTED STRATEGY: ", S1, " AVG RETURN: ", A1).

+!choose_max_strategy(S1, A1, S2, A2, S3, A3, S4, A4)
    : A2 > A1 & A2 >= A3 & A2 >= A4
<-
    -current_strategy(_);
    +current_strategy(S2);
    .println("SELECTED STRATEGY: ", S2, " AVG RETURN: ", A2).

+!choose_max_strategy(S1, A1, S2, A2, S3, A3, S4, A4)
    : A3 > A1 & A3 > A2 & A3 >= A4
<-
    -current_strategy(_);
    +current_strategy(S3);
    .println("SELECTED STRATEGY: ", S3, " AVG RETURN: ", A3).

+!choose_max_strategy(S1, A1, S2, A2, S3, A3, S4, A4)
    : A4 > A1 & A4 > A2 & A4 > A3
<-
    -current_strategy(_);
    +current_strategy(S4);
    .println("SELECTED STRATEGY: ", S4, " AVG RETURN: ", A4).



