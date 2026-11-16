run_id(3).
seed(42).

round(1).
max_rounds(100).
exploration_rounds(20).

active_agent(agent1).
active_agent(agent2).
active_agent(agent3).
active_agent(agent4).
active_agent(agent5).
active_agent(agent6).
active_agent(agent7).
active_agent(agent8).

endowment(10).
market1_return(5).
cpr_a(23).
cpr_b(0.25).

// A centralized communication occurs at the END of every fifth round.
// The selected bid will first be played in the following round.
comm_interval(5).
//starting goals
!start.
// plans
+!start <-
    .println("STARTING SIM");
    !apply_gui_config;
    !start_round.

+!apply_gui_config
<-
    if(strips.load_config(RunId, Seed, Rounds)) {
        -max_rounds(_);
        +max_rounds(Rounds);

        -seed(_);
        +seed(Seed);

        -run_id(_);
        +run_id(RunId);
        .println(
                    "GUI CONFIG APPLIED: ",
                    RunId, " ", Seed, " ", Rounds
        );
    } else {
        .println("NO GUI CONFIG FOUND, USING DEFAULTS");
    }.
    
+!start_round
    : round(Round)
    & seed(Seed)
    & run_id(RunId)
<-
    .println("");
    .println("===============");
    .println("STARTING ROUND: ", Round);
    .println("===============");

    //.broadcast(tell, start_round(Round)).

    for(active_agent(A))
    {
        .send(A, tell, start_round(RunId, Round, Seed));
    }
    .println("").



@submit_bid[atomic] // otherwise race condition triggers mutliple recalcs of round
+!submit_bid(Round, Bid, Strategy)[source(Requester)]
    : round(Round)
    & Bid >= 0
    & Bid <= 10
    & not bid(Requester, Round, _)
<-
    +bid(Requester, Round, Bid);
    +played_strategy(Requester, Round, Strategy);
    .println(
        "ROUND ", Round,
        " BY: ", Requester,
        " -> Market 2: ", Bid
    );

    !check_all_bids(Round).

+!check_all_bids(Round)
    : bid(agent1, Round, _)
    & bid(agent2, Round, _)
    & bid(agent3, Round, _)
    & bid(agent4, Round, _)
    & bid(agent5, Round, _)
    & bid(agent6, Round, _)
    & bid(agent7, Round, _)
    & bid(agent8, Round, _)
    & not round_calculated(Round)
<-
    +round_calculated(Round);
    !calculate_round(Round).

+!check_all_bids(_)
<-
    true.

+!calculate_round(Round)
    : bid(agent1, Round, B1)
    & bid(agent2, Round, B2)
    & bid(agent3, Round, B3)
    & bid(agent4, Round, B4)
    & bid(agent5, Round, B5)
    & bid(agent6, Round, B6)
    & bid(agent7, Round, B7)
    & bid(agent8, Round, B8)
    & market1_return(W)
    & cpr_a(CprA)
    & cpr_b(CprB)
    & seed(Seed)
    & run_id(RunId)
<-
    Total = B1+B2+B3+B4+B5+B6+B7+B8;
    Average = Total / 8;

    GroupMarket2Return =
    Total * (CprA - CprB * Total);

    OpportunityCost =
        W * Total;

    GroupRent =
        GroupMarket2Return - OpportunityCost;

    OptimalBid =
        (CprA - W) / (2 * CprB);

    OptimalMarket2Return =
        OptimalBid * (CprA - CprB * OptimalBid);

    OptimalRent =
        OptimalMarket2Return - W * OptimalBid;

    RentPct =
        100 * GroupRent / OptimalRent;

    Distance = math.abs(Total - OptimalBid);
    +round_metrics(Round, Total, RentPct, Distance);
    .println(
    "ROUND ", Round,
    " | M2=", Total,
    " | GROUP AVG = ", Average,
    " | RENT=", GroupRent,
    " | % OPTIMUM=", RentPct,
    " | DISTANCE=", Distance
    );
    //results.append("results/rounds.csv", Seed, RunId, Round, Total, Average, GroupRent, RentPct);
    results.append(
        "results/centralized/rounds.csv",
        RunId, Seed, Round,
        Total, Average, GroupRent, RentPct
    );
    !calculate_returns(Round, Total, Average).

+!calculate_returns(Round, Total, Average)
<-
    for (
        seed(Seed)
        & bid(A, Round, Bid)
        & played_strategy(A, Round, Strategy)
        & endowment(E)
        & market1_return(W)
        & cpr_a(CprA)
        & cpr_b(CprB)
        & run_id(RunId)
    ) {
        Market1 = W * (E - Bid);
        Market2 = Bid * (CprA - CprB * Total);
        Payoff = Market1 + Market2;
        
        //results.append("results/agents.csv", Seed, Round, A, Strategy, Bid, Market1, Market2, Payoff);
        results.append(
            "results/centralized/agents.csv",
            RunId, Seed, Round,
            A, Strategy, Bid,
            Market1, Market2, Payoff
        );

        strips.emit_event(agent_result(Round, A, Bid, Payoff, Strategy));
        .println(
            A,
            " | M2 bid: ", Bid,
            " | M1 return: ", Market1,
            " | M2 return: ", Market2,
            " | TOTAL: ", Payoff
        );

        .send(A, achieve, round_result(Round, Bid, Total, Average, Market1, Market2, Payoff)
        );
    }.

@receive_counterfactual[atomic]
+!counterfactual_bid(Round, Strategy, CandidateBid, CounterPayoff, ExpectedCount)[source(A)]
    : active_agent(A)
    & not cf_bid(A, Round, Strategy, _, _)
<-
    +cf_bid(A, Round, Strategy, CandidateBid, CounterPayoff);

    .count(cf_bid(A, Round, _, _, _), Count);

    !check_agent_counterfactuals(A, Round, Count, ExpectedCount);

    .println(
        "CF FROM ", A,
        " | ROUND ", Round,
        " | STRATEGY ", Strategy,
        " | BID ", CandidateBid,
        " | PAYOFF ", CounterPayoff
    ).    

+!check_agent_counterfactuals(
    A,
    Round,
    Count,
    ExpectedCount
)
    : Count == ExpectedCount
    & not cf_finished(A, Round)
<-
    +cf_finished(A, Round);

    .println(
        A,
        " FINISHED COUNTERFACTUALS: ",
        Count
    );

    .count(
        cf_finished(_, Round),
        FinishedCount
    );

    !check_all_counterfactuals(
        Round,
        FinishedCount
    ).    

+!check_agent_counterfactuals(
    _,
    _,
    Count,
    ExpectedCount
)
    : Count < ExpectedCount
<-
    true.


+!request_best_bid_suggestions(Round)
<-
    for(active_agent(A)) {
        .send(
            A,
            achieve,
            send_best_comm_bid(Round)
        );
    }.

+!check_all_counterfactuals(Round, 8)
<-
    .println(
        "ALL AGENTS FINISHED COUNTERFACTUALS FOR ROUND ",
        Round
    );

    //!find_best_social_strategy(Round).
    !maybe_central_communication(Round).

+!check_all_counterfactuals(_, Count)
    : Count < 8
<- 
    true.


@finish_agent[atomic]
+round_finished(Round)[source(A)]
    : round(Round)
    & active_agent(A)
    & not finished(A, Round)
<-
    +finished(A, Round);

    .count(finished(_, Round), Count);

    !check_finished_count(Round, Count).


+!check_finished_count(Round, 8)
    : round_metrics(Round, Total, RentPct, Distance)
<-
    strips.emit_event(round_finished(Round, Total, RentPct, Distance));
    .println("ALL AGENTS FINISHED ROUND ", Round);
    -round_metrics(Round, _, _, _);
    +normal_round_finished(Round);
    !maybe_advance_round(Round).

+!check_finished_count(_, Count)
    : Count < 8
<-
    true.

+!maybe_advance_round(Round)
    : normal_round_finished(Round)
    & social_choice_finished(Round)
<-
    !advance_round.

+!maybe_advance_round(_)
<-
    true.

+!advance_round
    : round(Round)
    & max_rounds(Max)
    & Round < Max
<-
    NextRound = Round + 1;

    -round(Round);
    +round(NextRound);

    for(central_adoption_done(A, Round))
    {
        -central_adoption_done(A, Round);
    };
    !start_round.

+!advance_round
    : round(Round)
    & max_rounds(Max)
    & Round >= Max
<-
    strips.emit_event(simulation_finished(Round));
    .println("SIMULATION FINISHED AFTER ", Round, " ROUNDS");
    .stopMAS(500).
    
+!apply_strips_decision(
    Round,
    BestBid 
)
<-
    .println(
        "ASKING STRIPS TO REACH GOAL FOR ",
        BestBid
    );

    if(strips.plan(BestBid)) {
        // strips.emit_event(
        //     planner_decision(
        //         Round,
        //         [],
        //         [enforce_bid(BestBid)],
        //         centralized
        //     )

        //);
        .println("STRIPS SUCCESS: ", BestBid);
    } else {
        .println("STRIPS FAILURE: ", BestBid);
        strips.emit_event(
            planner_failed(Round, "STRIPS could not find a plan for the selected bid")
        );
    };

    .println(
        "STRIPS PLAN FOUND: enforce_bid(",
        BestBid,
        ")"
    );
    
    for(active_agent(A)) {
        .send(A, achieve, adopt_central_bid(Round, BestBid));
    }.
@central_adoption_ack[atomic]
+central_bid_adopted(Round)[source(A)]
    : round(Round)
    & active_agent(A)
    & not central_adoption_done(A, Round)
<-
    +central_adoption_done(A, Round);

    .count(
        central_adoption_done(_, Round),
        Count
    );

    .println(
        "CENTRAL BID ACK ",
        A,
        " ROUND ",
        Round,
        " | ",
        Count,
        "/8"
    );

    !check_central_adoption(
        Round,
        Count
    ).

+!check_central_adoption(Round, 8)
<-
    .println(
        "ALL AGENTS ADOPTED CENTRAL BID FOR ROUND ",
        Round
    );

    +social_choice_finished(Round);

    !maybe_advance_round(Round).


+!check_central_adoption(_, Count)
    : Count < 8
<-
    true.   


// Exploration: no central coordination in rounds 1–19.
+!maybe_central_communication(Round)
    : exploration_rounds(Min)
    & Round < Min
<-
    +social_choice_finished(Round);
    !maybe_advance_round(Round).

// First central selection at round 20,
// then every fifth round.
+!maybe_central_communication(Round)
    : comm_interval(Interval)
    & exploration_rounds(Min)
    & Round >= Min
    & Round mod Interval == 0
<-
    !request_best_bid_suggestions(Round).

// Normal rounds between central selections.
+!maybe_central_communication(Round)
    : comm_interval(Interval)
    & exploration_rounds(Min)
    & Round >= Min
    & Round mod Interval \== 0
<-
    +social_choice_finished(Round);
    !maybe_advance_round(Round).

@receive_comm_bid[atomic]
+!best_bid_suggestion(Round, Bid, Strategy, Avg)[source(A)]
    : round(Round)
    & active_agent(A)
    & not comm_bid(A, Round, _, _, _)
<-
    +comm_bid(A, Round, Bid, Strategy, Avg);

    .count(comm_bid(_, Round, _, _, _), Count);

    !check_all_comm_bids(Round, Count).    

+!check_all_comm_bids(_, Count)
    : Count < 8
<- 
    true. 

+!check_all_comm_bids(Round, 8)
    : market1_return(W)
    & cpr_a(CprA)
    & cpr_b(CprB)
<-
    .findall([A, Bid, Strategy, Avg],
    comm_bid(A, Round, Bid, Strategy, Avg),
    Suggestions);

    !choose_best_uniform_bid(Round, Suggestions, W, CprA, CprB).

+!choose_best_uniform_bid(Round, [[_, Bid, Strategy, _] | Rest], W, CprA, CprB) 
<-  
    !calculate_uniform_rent(Bid, W, CprA, CprB, Rent);

    !scan_uniform_bids(Round, Rest, Bid, Strategy, Rent, W, CprA, CprB).

+!scan_uniform_bids(Round, [[_, Bid, Strategy, _] | Rest], BestBid, BestStrategy, BestRent, W, CprA, CprB)
<-
    !calculate_uniform_rent(Bid, W, CprA, CprB, Rent);

    !compare_uniform_bid(Round, Rest, Bid, Strategy, Rent, BestBid, BestStrategy, BestRent, W, CprA, CprB).



+!compare_uniform_bid(Round, Rest, Bid, Strategy, Rent, BestBid, BestStrategy, BestRent, W, CprA, CprB)
    : (Rent > BestRent) |
      ((Rent == BestRent) & (Bid < BestBid))
<-
    !scan_uniform_bids(
        Round, Rest, Bid, Strategy, Rent,
        W, CprA, CprB
    ).


+!compare_uniform_bid(Round, Rest, Bid, Strategy, Rent, BestBid, BestStrategy, BestRent, W, CprA, CprB)
    : (Rent < BestRent) |
      ((Rent == BestRent) & (Bid >= BestBid))
<-
    !scan_uniform_bids(
        Round, Rest, BestBid, BestStrategy, BestRent,
        W, CprA, CprB
    ).
+!scan_uniform_bids(Round, [], BestBid, SourceStrategy, BestRent, _, _, _)
<-
    .println(
        "CENTRAL BEST BID ROUND ",
        Round,
        ": ",
        BestBid,
        " | SOURCE ",
        SourceStrategy,
        " | GROUP RENT ",
        BestRent);

    ?run_id(RunId);
    ?seed(Seed);
    results.append(
        "results/centralized/central_choices.csv",
        RunId, Seed, Round, BestBid, BestRent
    );

    !apply_strips_decision(Round, BestBid).


+!calculate_uniform_rent(
    Bid,
    W,
    CprA,
    CprB,
    Rent
)
<-
    Total = 8 * Bid;

    Rent =
        Total * (CprA - CprB * Total)
        - W * Total.