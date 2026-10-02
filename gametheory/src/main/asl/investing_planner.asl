run_id(3).
seed(42).

round(1).
max_rounds(100).

active_agent(agent1).
active_agent(agent2).
active_agent(agent3).
active_agent(agent4).
active_agent(agent5).
active_agent(agent6).
active_agent(agent7).
active_agent(agent8).

candidate_strategy(total_return_1).
candidate_strategy(total_return_2).
candidate_strategy(total_return_3).
candidate_strategy(total_return_4).
candidate_strategy(total_return_all_dec3).
candidate_strategy(total_return_all_dec5).

candidate_strategy(unit_return_1).
candidate_strategy(unit_return_2).
candidate_strategy(unit_return_3).
candidate_strategy(unit_return_4).
candidate_strategy(unit_return_all_dec3).
candidate_strategy(unit_return_all_dec5).

candidate_strategy(group_average_0).
candidate_strategy(group_average_1).
candidate_strategy(group_average_2).
candidate_strategy(group_average_3).

endowment(10).
market1_return(5).
cpr_a(23).
cpr_b(0.25).
//starting goals
!start.
// plans
+!start <- 
    .println("STARTING SIM");
    !start_round.


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

    .println(
    "ROUND ", Round,
    " | M2=", Total,
    " | GROUP AVG = ", Average,
    " | RENT=", GroupRent,
    " | % OPTIMUM=", RentPct
    );
    //results.append("results/rounds.csv", Seed, RunId, Round, Total, Average, GroupRent, RentPct);
    results.append(
        "results/rounds.csv",
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
            "results/agents.csv",
            RunId, Seed, Round,
            A, Strategy, Bid,
            Market1, Market2, Payoff
        );

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

+!check_all_counterfactuals(Round, 8)
<-
    .println(
        "ALL AGENTS FINISHED COUNTERFACTUALS FOR ROUND ",
        Round
    );

    !find_best_social_strategy(Round).

+!check_all_counterfactuals(_, Count)
    : Count < 8
<- 
    true.

+! evaluate_social_strategies(Round, [Strategy | Rest], W, CprA, CprB)
<-
    !evaluate_social_strategy(Round, Strategy, W, CprA, CprB);

    !evaluate_social_strategies(Round, Rest, W, CprA, CprB).

+! evaluate_social_strategies(_, [], _, _, _)
<-  
    !select_best_social_strategy(Round).

+!evaluate_social_strategy(
    Round,
    Strategy,
    W,
    CprA,
    CprB
)
<-
    .findall(
        Bid,
        cf_bid(_, Round, Strategy, Bid, _),
        Bids
    );

    !sum_bids(Bids, 0, TotalBid);

    GroupMarket2Return =
        TotalBid * (CprA - CprB * TotalBid);

    OpportunityCost =
        W * TotalBid;

    GroupRent =
        GroupMarket2Return - OpportunityCost;

    +social_strategy_score(
        Round,
        Strategy,
        GroupRent
    );

    .println(
        "SOCIAL STRATEGY ",
        Strategy,
        " | TOTAL BID ",
        TotalBid,
        " | RENT ",
        GroupRent
    ).

+!sum_bids([Bid | Rest], Acc, Total)
<-
    NewAcc = Acc + Bid;
    !sum_bids(Rest, NewAcc, Total).

+!sum_bids([], Total, Total)
<-
    true.
+!find_best_social_strategy(Round)
: market1_return(W)
& cpr_a(CprA)
& cpr_b(CprB)
<-
    for(social_strategy_score(Round, S, R))
    {
        -social_strategy_score(Round, S, R);
    };

    for(
        candidate_strategy(S)
    )
    {
        !maybe_evaluate_social_strategy(Round, S, W, CprA, CprB);
    };

    !select_best_social_strategy(Round).

+!maybe_evaluate_social_strategy(Round, Strategy, W, CprA, CprB)
    : cf_bid(_, Round, Strategy, _, _)
<-
    !evaluate_social_strategy(Round, Strategy, W, CprA, CprB).

+!maybe_evaluate_social_strategy(Round,Strategy, _, _, _)
    : not cf_bid(_, Round, Strategy, _, _)
<-
    true.

+!select_best_social_strategy(Round)
<-
    .findall(
        [Strategy, Rent],
        social_strategy_score(Round, Strategy, Rent),
        Scores
    );

    !choose_best_social_strategy(
        Round,
        Scores
    ).

+!choose_best_social_strategy(
    Round,
    [[Strategy, Rent] | Rest]
)
<-
    !scan_social_strategies(
        Round,
        Rest,
        Strategy,
        Rent
    ).

+!scan_social_strategies(
    Round,
    [[Strategy, Rent] | Rest],
    BestStrategy,
    BestRent
)
    : Rent > BestRent
<-
    !scan_social_strategies(
        Round,
        Rest,
        Strategy,
        Rent
    ).

+!scan_social_strategies(
    Round,
    [[_, Rent] | Rest],
    BestStrategy,
    BestRent
)
    : BestRent >= Rent
<-
    !scan_social_strategies(
        Round,
        Rest,
        BestStrategy,
        BestRent
    ).
+!scan_social_strategies(
    Round, 
    [],
    BestStrategy,
    BestRent
)        
<- 
    .println(
        "BEST SOCIAL STRATEGY ROUND ",
        Round,
        ": ",
        BestStrategy,
        " | GROUP RENT = ",
        BestRent
    );
    -best_social_strategy(Round, _, _);
    +best_social_strategy(Round, BestStrategy, BestRent).

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
<-
    .println("ALL AGENTS FINISHED ROUND ", Round);
    !advance_round.

+!check_finished_count(_, Count)
    : Count < 8
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

    for(cf_finished(A, Round)) {
        -cf_finished(A, Round);
    };

    for(cf_bid(A, Round, S, B, P)) {
        -cf_bid(A, Round, S, B, P);
    };
    !start_round.

+!advance_round
    : round(Round)
    & max_rounds(Max)
    & Round >= Max
<-
    .println("SIMULATION FINISHED AFTER ", Round, " ROUNDS");
    // .stopMAS(500).
    true.
