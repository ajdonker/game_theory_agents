// Investor state and strategy definitions
endowment(10).

last_bid(0).
last_total_return(0).


last_group_total(0). 
last_group_average(0).

market1_return(5).
cpr_a(23).
cpr_b(0.25).

// Strategy rules: name, family, increment, decrement (where applicable).
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

strategy_score_window(10).

// Available strategy definitions (the private pool is sampled once per agent).
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

    // Clear prior-round counterfactuals before generating new candidates.
    for(counterfactual_return(OldRound, Strategy, Payoff)) {
        -counterfactual_return(OldRound, Strategy, Payoff);
    };

    !pick_random_strategies(Seed);

    !generate_strategy_bids(Round);
    // A centrally assigned rule may not be in this agent's random pool.
    !generate_assigned_strategy_bid;
    !play_current_strategy(Round).

//plans
+!init_all_strategy_states
    : all_strategies(All)
<- 
    !init_strategy_list_all(All).

+!init_strategy_list_all([S | Rest])
<-
    !init_strategy_state(S);
    !init_strategy_list_all(Rest).

+!init_strategy_list_all([])
<- 
    true.

+! pick_random_strategies(Seed)
    : not strategies_picked
    & all_strategies(All)
<- 
    .my_name(Me);
    ?agent_index(Me, Index);

    AgentSeed = Seed * 100 + Index;

    !init_all_strategy_states;

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

// Private strategies continue to be evaluated every round.
+!generate_strategy_bids(_)
<-
    for(strategy_score(Strategy, _, _)) {
        !generate_strategy_bid(Strategy);
    }.

// Generate the assigned rule separately when it is outside the private pool.
+!generate_assigned_strategy_bid
    : following_central_strategy(Strategy)
    & not strategy_score(Strategy, _, _)
<-
    !generate_strategy_bid(Strategy).

+!generate_assigned_strategy_bid
<-
    true.

+!generate_strategy_bid(Strategy)
    : strategy_rule(Strategy, total_return, Increment, Decrement)
    & strategy_last_bid(Strategy, LastBid)
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

    // A shared rule outside the private pool must learn from its actual outcome.
    !update_assigned_strategy_state(ActualBid, Market1, Market2, ActualPayoff);

    !maybe_select_strategy(Round);

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

    -last_group_total(_);
    +last_group_total(GroupTotal);

    -last_group_average(_);
    +last_group_average(GroupAverage).

// Keep counterfactual scores for the original four private strategies only.
+! evaluate_strategies(Round, ActualBid, GroupTotal)
<-
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
    & planner_name(Planner)
    & strategy_pool(Pool)
<-
    .my_name(Me);

    CounterTotal = GroupTotal - ActualBid + AlternativeBid;

    CounterMarket1 = W * (E - AlternativeBid);

    CounterMarket2 = AlternativeBid * (CprA - CprB * CounterTotal);

    CounterPayoff = CounterMarket1 + CounterMarket2;

    // Used for individual deviation decisions after central coordination.
    +counterfactual_return(Round, Strategy, CounterPayoff);

    !update_total_return_direction(Strategy, CounterPayoff);

    ?strategy_score_window(Window);
    ExpiredRound = Round - Window;
    !expire_oldest_payoff(Strategy, ExpiredRound);

    ?strategy_score(Strategy, CurrentSum, CurrentN);

    NewSum = CurrentSum + CounterPayoff;
    NewN = CurrentN + 1;

    -strategy_score(Strategy, CurrentSum, CurrentN);
    +strategy_score(Strategy, NewSum, NewN);
    +strategy_payoff_history(Strategy, Round, CounterPayoff);

    !update_strategy_last_bid(Strategy, AlternativeBid);

    !update_strategy_returns(Strategy, CounterMarket1, CounterMarket2);

    .length(Pool, PoolSize);
    // Planner uses private-pool counterfactuals as the completion barrier.
    .send(Planner, achieve, counterfactual_bid(Round, Strategy, AlternativeBid, CounterPayoff, PoolSize));
    results.append(
        "results/centralized/strategies.csv",
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

+!expire_oldest_payoff(Strategy, ExpiredRound)
    : strategy_payoff_history(Strategy, ExpiredRound, OldPayoff)
    & strategy_score(Strategy, Sum, N)
<-
    NewSum = Sum - OldPayoff;
    NewN = N - 1;
     
    -strategy_payoff_history(Strategy, ExpiredRound, OldPayoff);
    -strategy_score(Strategy, Sum, N);
    +strategy_score(Strategy, NewSum, NewN).

+!expire_oldest_payoff(Strategy, ExpiredRound)
    : not strategy_payoff_history(Strategy, ExpiredRound, _)
<-
    true.

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

// Shared rule is part of the private pool: normal counterfactual evaluation
// has already updated its state (its predicted bid equals the actual bid).
+!update_assigned_strategy_state(_, _, _, _)
    : following_central_strategy(Strategy)
    & strategy_score(Strategy, _, _)
<-
    true.

// Shared rule is outside the private pool: learn its ACTUAL outcome without
// adding it to strategy_score/3 or changing the seeded four-rule pool.
+!update_assigned_strategy_state(ActualBid, Market1, Market2, ActualPayoff)
    : following_central_strategy(Strategy)
    & not strategy_score(Strategy, _, _)
<-
    !update_total_return_direction(Strategy, ActualPayoff);
    !update_strategy_last_bid(Strategy, ActualBid);
    !update_strategy_returns(Strategy, Market1, Market2).

+!update_assigned_strategy_state(_, _, _, _)
    : not following_central_strategy(_)
<-
    true.

// Every third round, private agents choose their best average-payoff rule.
+!maybe_select_strategy(Round)
    : Round mod 3 == 0
    & not following_central_strategy(_)
<-
    !select_best_strategy.

// An agent following central coordination can revert to a private rule only
// if its own current-round counterfactual payoff would have been higher.
+!maybe_select_strategy(Round)
    : Round mod 3 == 0
    & following_central_strategy(_)
    & last_total_return(ActualPayoff)
<-
    !consider_central_defection(Round, ActualPayoff).
    true.

+!maybe_select_strategy(Round)
    : Round mod 3 \== 0
<-
    true.

+!consider_central_defection(Round, ActualPayoff)
    : counterfactual_return(Round, _, _)
<-
    .findall([Payoff, Strategy],
        counterfactual_return(Round, Strategy, Payoff),
        Alternatives);
    .sort(Alternatives, Sorted);
    .length(Sorted, Size);
    Last = Size - 1;
    .nth(Last, Sorted, [BestPayoff, BestStrategy]);
    !switch_from_central_if_better(Round, ActualPayoff, BestStrategy, BestPayoff).

+!consider_central_defection(Round, _)
    : not counterfactual_return(Round, _, _)
<-
    true.

+!switch_from_central_if_better(Round, ActualPayoff, BestStrategy, BestPayoff)
    : following_central_strategy(ImposedStrategy)
    & current_strategy(ImposedStrategy)
    & BestPayoff > ActualPayoff
    & candidate_bid(BestStrategy, AlternativeBid)
    & last_bid(ActualBid)
    & run_id(RunId)
    & planner_seed(Seed)
<-
    .my_name(Me);
    results.append(
        "results/centralized/defections.csv",
        RunId, Seed, Round, Me, ImposedStrategy,
        BestStrategy, ActualBid, AlternativeBid, ActualPayoff, BestPayoff
    );
    -following_central_strategy(ImposedStrategy);
    -current_strategy(ImposedStrategy);
    +current_strategy(BestStrategy);
    .println("CENTRAL DEFECTION: ", Me,
        " round ", Round,
        " central strategy ", ImposedStrategy,
        " -> ", BestStrategy,
        " bid ", ActualBid, " -> ", AlternativeBid).

+!switch_from_central_if_better(_, ActualPayoff, _, BestPayoff)
    : ActualPayoff >= BestPayoff
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

+!simulate_all_strategy_bids(Round)[source(Planner)]
    : all_strategies(All)
<-
    !collect_social_bids(All, [], Results);

    .send(Planner, achieve, simulated_social_bids(Round, Results)).

+!collect_social_bids([], Acc, Acc)
<-
    true.

+!collect_social_bids([Strategy | Rest], Acc, Results)
<- 
    !generate_strategy_bid(Strategy);

    ?candidate_bid(Strategy, Bid);

    !collect_social_bids(Rest, [[Strategy, Bid] | Acc], Results).

// Adopt a common decision RULE. Each agent computes its own bid next round.
// Preserve the private strategy pool; it remains the source of future defections.
+!adopt_central_strategy(Round, Strategy)[source(Planner)]
<-
    -following_central_strategy(_);
    -current_strategy(_);
    +current_strategy(Strategy);
    +following_central_strategy(Strategy);
    .println("CENTRAL AUTHORITY ROUND ", Round, " -> STRATEGY ", Strategy);
    .send(Planner, tell, central_strategy_adopted(Round)).
