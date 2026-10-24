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

all_agents([agent1, agent2, agent3, agent4, agent5, agent6, agent7, agent8]).
comm_interval(5).
strat_reeval_interval(3).
trust_threshold(0.6).
trust_learning_rate(0.02).
trust_max_step(0.1).
default_trust(0.5).
max_coalition_peers(3).
coalition_bid_threshold(2). // Used for partner selection, not strategy/bid imposition.

// Coalition strategy sharing: trust-based mutual peers exchange their
// best available strategies, not numerical bid instructions.
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
    !init_trust;
    !pick_random_strategies(Seed);
    !generate_strategy_bids(Round);
    !play_current_strategy(Round).

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

    // Persist random initialization to verify recommendations do not expand the pool.
    ?run_id(RunId);
    .my_name(Me);
    results.append("results/coalition_strat/strategy_pools.csv",
                   RunId, Seed, Me, S1, S2, S3, S4);

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

+!init_trust
    : all_agents(Agents)
    & not trust_initialized
    & default_trust(Default)
<-
    .my_name(Me);
    +trust_initialized;
    !init_trust_except_me(Agents, Me, Default).

+!init_trust
    : trust_initialized
<-
    true.

+!init_trust_except_me([Agent | Rest], Me, Default)
    : Agent \== Me
<-
    +trust(Agent, Default);
    !init_trust_except_me(Rest, Me, Default).

+!init_trust_except_me([Agent | Rest], Me, Default)
    : Agent == Me
<-
    !init_trust_except_me(Rest, Me, Default).

+!init_trust_except_me([], _, _)
<-
    true.

// generation plans end

//
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

    // Every round: gather bids to update trust and complete this round.
    +coalition_context(Round, ActualBid, GroupTotal);
    .my_name(Me);
    +agent_bid(Me, Round, ActualBid);
    .broadcast(tell, observed_bid(Round, ActualBid));
    !check_coalition_observations(Round).

+observed_bid(Round, Bid)[source(Sender)]
    : not agent_bid(Sender, Round, _)
<-
    +agent_bid(Sender, Round, Bid);
    !check_coalition_observations(Round).

+observed_bid(Round, _)[source(Sender)]
    : agent_bid(Sender, Round, _)
<-
    true.

+!check_coalition_observations(Round)
    : coalition_context(Round, ActualBid, GroupTotal)
    & not coalition_observations_ready(Round)
<-
    .count(agent_bid(_, Round, _), Count);
    !check_coalition_observation_count(Round, Count, ActualBid, GroupTotal).

+!check_coalition_observations(_)
<-
    true.

@coalition_observation_barrier[atomic]
+!check_coalition_observation_count(Round, 8, ActualBid, GroupTotal)
    : not coalition_observations_ready(Round)
<-
    +coalition_observations_ready(Round);
    !update_coalition_trust(Round, ActualBid, GroupTotal);
    !after_coalition_trust_update(Round, ActualBid, GroupTotal).

+!after_coalition_trust_update(Round, ActualBid, GroupTotal)
    : comm_interval(Interval)
    & Round mod Interval == 0
<-
    !build_coalition_preferences(Round, ActualBid).

+!after_coalition_trust_update(Round, _, _)
    : comm_interval(Interval)
    & Round mod Interval \== 0
    & planner_name(Planner)
<-
    !maybe_select_strategy(Round);
    .send(Planner, tell, round_finished(Round)).

+!check_coalition_observation_count(_, Count, _, _)
    : Count < 8
<-
    true.

+!update_coalition_trust(Round, _, _)
    : Round == 1
<-
    true.

+!update_coalition_trust(Round, MyBid, GroupTotal)
    : Round > 1
    & endowment(E)
    & market1_return(W)
    & cpr_a(CprA)
    & cpr_b(CprB)
    & trust_learning_rate(Alpha)
    & trust_max_step(MaxStep)
<-
    PreviousRound = Round - 1;
    .my_name(Me);
    for(agent_bid(Other, Round, OtherBid)
        & agent_bid(Other, PreviousRound, PreviousBid)
        & Other \== Me
        & trust(Other, OldTrust)) {
        CounterTotal = GroupTotal - OtherBid + PreviousBid;
        CounterMarket1 = W * (E - MyBid);
        CounterMarket2 = MyBid * (CprA - CprB * CounterTotal);
        CounterPayoff = CounterMarket1 + CounterMarket2;
        ActualPayoff = CounterMarket1 + MyBid * (CprA - CprB * GroupTotal);
        RawChange = Alpha * (ActualPayoff - CounterPayoff);
        Change = math.max(-MaxStep, math.min(MaxStep, RawChange));
        NewTrust = math.max(0, math.min(1, OldTrust + Change));
        -trust(Other, OldTrust);
        +trust(Other, NewTrust);
    }.

+!build_coalition_preferences(Round, MyBid)
    : all_agents(Agents)
    & max_coalition_peers(MaxPeers)
    & trust_threshold(TrustThreshold)
    & coalition_bid_threshold(BidThreshold)
<-
    .my_name(Me);
    for(coalition_candidate(Round, _, Peer)) {
        -coalition_candidate(Round, _, Peer);
    };
    for(preferred_peer(Round, Peer)) {
        -preferred_peer(Round, Peer);
    };
    for(reported_trust(Round, Peer, _)) {
        -reported_trust(Round, Peer, _);
    };
    for(agent_bid(Peer, Round, PeerBid)
        & Peer \== Me
        & trust(Peer, MyTrust)
        & MyTrust >= TrustThreshold) {
        !consider_coalition_candidate(Round, Peer, PeerBid, MyBid, BidThreshold);
    };
    .findall(
        [Diff, Peer],
        coalition_candidate(Round, Diff, Peer),
        Candidates
    );
    .sort(Candidates, Sorted);
    !take_coalition_peers(Round, Sorted, MaxPeers);
    .findall(Peer, preferred_peer(Round, Peer), PreferredPeers);
    .broadcast(tell, coalition_preferences(Round, PreferredPeers));
    +coalition_preferences_ready(Round);
    !check_coalition_preferences(Round).

+!consider_coalition_candidate(Round, Peer, PeerBid, MyBid, BidThreshold)
    : math.abs(MyBid - PeerBid) <= BidThreshold
<-
    Diff = math.abs(MyBid - PeerBid);
    +coalition_candidate(Round, Diff, Peer).

+!consider_coalition_candidate(_, _, _, _, _)
<-
    true.

+!take_coalition_peers(_, _, Remaining)
    : Remaining <= 0
<-
    true.

+!take_coalition_peers(Round, [[_, Peer] | Rest], Remaining)
    : Remaining > 0
<-
    +preferred_peer(Round, Peer);
    Next = Remaining - 1;
    !take_coalition_peers(Round, Rest, Next).

+!take_coalition_peers(_, [], _)
<-
    true.

+coalition_preferences(Round, Peers)[source(Sender)]
    : not received_preferences(Round, Sender, _)
<-
    +received_preferences(Round, Sender, Peers);
    !check_coalition_preferences(Round).

+coalition_preferences(Round, _)[source(Sender)]
    : received_preferences(Round, Sender, _)
<-
    true.

+!check_coalition_preferences(Round)
    : all_agents(Agents)
    & coalition_preferences_ready(Round)
    & not coalition_ready(Round)
<-
    .length(Agents, AgentCount);
    Expected = AgentCount - 1;
    .count(received_preferences(Round, _, _), Count);
    !check_coalition_preference_count(Round, Count, Expected).

+!check_coalition_preferences(_)
<-
    true.

@coalition_preferences_barrier[atomic]
+!check_coalition_preference_count(Round, Count, Expected)
    : Count == Expected
    & not coalition_ready(Round)
<-
    +coalition_ready(Round);
    .my_name(Me);
    for(preferred_peer(Round, Peer)
        & received_preferences(Round, Peer, PeerPreferences)
        & .member(Me, PeerPreferences)) {
        +coalition_peer(Round, Peer);
    };
    .count(coalition_peer(Round, _), PeerCount);
    !start_coalition_exchange(Round).

+!check_coalition_preference_count(_, Count, Expected)
    : Count < Expected
<-
    true.

// Only reciprocally chosen peers exchange their preferred strategy.
+!start_coalition_exchange(Round)
    : coalition_context(Round, _, _)
    & planner_name(Planner)
<-
    .count(coalition_peer(Round, _), PeerCount);
    !exchange_or_finish(Round, PeerCount, Planner).

+!exchange_or_finish(Round, 0, Planner)
<-
    // Isolated agents keep their ordinary private strategy selection.
    !maybe_select_strategy(Round);
    .send(Planner, tell, round_finished(Round)).

+!exchange_or_finish(Round, PeerCount, _)
    : PeerCount > 0
<-
    !select_best_strategy;
    ?current_strategy(MyStrategy);
    ?strategy_score(MyStrategy, Sum, N);
    Average = Sum / N;
    for(coalition_peer(Round, Peer) & trust(Peer, TrustOfPeer)) {
        .send(Peer, tell,
              coalition_strategy_suggestion(Round, MyStrategy, Average, TrustOfPeer));
    };
    !check_coalition_strategy_ready(Round).

+coalition_strategy_suggestion(Round, Strategy, Average, SenderTrust)[source(Sender)]
    : not received_coalition_strategy(Round, Sender, _, _, _)
<-
    +received_coalition_strategy(Round, Sender, Strategy, Average, SenderTrust);
    !check_coalition_strategy_ready(Round).

+!check_coalition_strategy_ready(Round)
    : coalition_context(Round, _, _)
    & coalition_ready(Round)
    & not coalition_exchange_done(Round)
    & planner_name(Planner)
<-
    .count(coalition_peer(Round, _), Expected);
    .count(received_coalition_strategy(Round, Peer, _, _, _)
           & coalition_peer(Round, Peer), Count);
    !finish_coalition_strategy_exchange(Round, Expected, Count, Planner).

+!check_coalition_strategy_ready(_)
<-
    true.

@coalition_strategy_barrier[atomic]
+!finish_coalition_strategy_exchange(Round, Expected, Expected, Planner)
    : Expected > 0
    & not coalition_exchange_done(Round)
<-
    +coalition_exchange_done(Round);
    !select_coalition_supported_strategy(Round);
    !log_coalition_links(Round);
    .send(Planner, tell, round_finished(Round)).

+!finish_coalition_strategy_exchange(_, Expected, Count, _)
    : Count < Expected
<-
    true.

// A strategy can only be selected if it belongs to this agent's own pool.
// Trusted mutual peers provide endorsements; own historical payoff breaks ties.
+!select_coalition_supported_strategy(Round)
<-
    for(strategy_score(Strategy, Sum, N) & N > 0) {
        .count(received_coalition_strategy(Round, Peer, Strategy, _, _)
               & coalition_peer(Round, Peer), Votes);
        Average = Sum / N;
        +coalition_rank(Round, Votes, Average, Strategy);
    };
    .findall([Votes, Average, Strategy],
             coalition_rank(Round, Votes, Average, Strategy), Ranked);
    .sort(Ranked, Sorted);
    .length(Sorted, Size);
    Last = Size - 1;
    .nth(Last, Sorted, [Votes, Average, Chosen]);
    -current_strategy(_);
    +current_strategy(Chosen);
    .my_name(Me);
    ?run_id(RunId);
    ?planner_seed(Seed);
    results.append("results/coalition_strat/communication.csv",
                   RunId, Seed, Round, Me, Chosen, Votes, Average);
    for(coalition_rank(Round, V, A, S)) { -coalition_rank(Round, V, A, S); }.

// Preserve trust analyses: one directed observation for each mutual link.
+!log_coalition_links(Round)
    : coalition_context(Round, MyBid, _)
    & run_id(RunId)
    & planner_seed(Seed)
<-
    .my_name(Me);
    for(coalition_peer(Round, Peer)
        & agent_bid(Peer, Round, PeerBid)
        & trust(Peer, MyTrust)
        & received_coalition_strategy(Round, Peer, _, _, PeerTrust)) {
        results.append("results/coalition_strat/coalitions.csv",
                       RunId, Seed, Round, Me, Peer,
                       MyBid, PeerBid, MyTrust, PeerTrust);
    }.

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

    results.append(
    "results/coalition_strat/strategies.csv",
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

+! maybe_select_strategy(Round)
    : strat_reeval_interval(Interval)
    & Round mod Interval == 0
<-
    !select_best_strategy.

+! maybe_select_strategy(Round)
    : strat_reeval_interval(Interval)
        & Round mod Interval \== 0
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
