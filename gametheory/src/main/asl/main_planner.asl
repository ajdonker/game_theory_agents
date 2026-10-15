planner_enabled(true).
run_id(3).
seed(42).

round(1).
max_rounds(300).

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
intervention(no_intervention).
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
    & intervention(CurrentIntervention)
<-
    .println("");
    .println("===============");
    .println("STARTING ROUND: ", Round);
    .println("===============");

    +round_mode(Round, CurrentIntervention);

    //.broadcast(tell, start_round(Round)).

    for(active_agent(A))
    {
        .send(A, tell, start_round(RunId, Round, Seed, CurrentIntervention));
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
    & intervention(CurrentIntervention)
<-
    Total = B1+B2+B3+B4+B5+B6+B7+B8;
    Average = Total / 8;

    GroupMarket2Return =
    Total * (CprA - CprB * Total);

    OpportunityCost =
        W * Total;

    GroupRent =
        GroupMarket2Return - OpportunityCost;

    OptimalGroupInvestment =
        (CprA - W) / (2 * CprB);

    OptimalMarket2Return =
        OptimalGroupInvestment * (CprA - CprB * OptimalGroupInvestment);

    OptimalRent =
        OptimalMarket2Return - W * OptimalGroupInvestment;

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
        "results/no_comm/rounds.csv",
        RunId, Seed, Round,
        Total, Average, GroupRent, RentPct
    );

    strips.decide(Total, OptimalGroupInvestment, B1, B2, B3, B4, B5, B6, B7, B8, CurrentIntervention, Intervention);
    !apply_intervention(Intervention);
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
            "results/no_comm/agents.csv",
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

@central_bid_suggestions[atomic]
+!best_bid_suggestion(Round, Bid, Strategy, Average)[source(A)]
    : round(Round)
    & round_mode(Round, centralized)
    & active_agent(A)
    & Bid >= 0
    & Bid <= 10
    & not central_bid_suggestion(A, Round, _, _, _)
<-
    +central_bid_suggestion(A, Round, Bid, Strategy, Average);
    .count(central_bid_suggestion(_, Round, _, _, _), Count);
    !check_central_bid_suggestions(Round, Count).

+!check_central_bid_suggestions(Round, 8)
    : market1_return(W)
    & cpr_a(CprA)
    & cpr_b(CprB)
<-
    .findall(
        [Bid, Strategy],
        central_bid_suggestion(_, Round, Bid, Strategy, _),
        Suggestions
    );
    !choose_central_bid(Round, Suggestions, W, CprA, CprB).

+!check_central_bid_suggestions(_, Count)
    : Count < 8
<-
    true.

+!choose_central_bid(
    Round,
    [[Bid, Strategy] | Rest],
    W,
    CprA,
    CprB
)
<-
    !calculate_central_bid_rent(Bid, W, CprA, CprB, Rent);
    !scan_central_bids(
        Round,
        Rest,
        Bid,
        Strategy,
        Rent,
        W,
        CprA,
        CprB
    ).

+!scan_central_bids(
    Round,
    [[Bid, Strategy] | Rest],
    BestBid,
    BestStrategy,
    BestRent,
    W,
    CprA,
    CprB
)
<-
    !calculate_central_bid_rent(Bid, W, CprA, CprB, Rent);
    !compare_central_bid(
        Round,
        Rest,
        Bid,
        Strategy,
        Rent,
        BestBid,
        BestStrategy,
        BestRent,
        W,
        CprA,
        CprB
    ).

+!compare_central_bid(
    Round,
    Rest,
    Bid,
    Strategy,
    Rent,
    _,
    _,
    BestRent,
    W,
    CprA,
    CprB
)
    : Rent > BestRent
<-
    !scan_central_bids(
        Round,
        Rest,
        Bid,
        Strategy,
        Rent,
        W,
        CprA,
        CprB
    ).

+!compare_central_bid(
    Round,
    Rest,
    _,
    _,
    Rent,
    BestBid,
    BestStrategy,
    BestRent,
    W,
    CprA,
    CprB
)
    : BestRent >= Rent
<-
    !scan_central_bids(
        Round,
        Rest,
        BestBid,
        BestStrategy,
        BestRent,
        W,
        CprA,
        CprB
    ).

+!scan_central_bids(
    Round,
    [],
    BestBid,
    BestStrategy,
    BestRent,
    _,
    _,
    _
)
<-
    .println(
        "CENTRAL BEST BID ROUND ",
        Round,
        ": ",
        BestBid,
        " | SOURCE ",
        BestStrategy,
        " | GROUP RENT ",
        BestRent
    );
    !adopt_central_bid(Round, BestBid).

+!calculate_central_bid_rent(Bid, W, CprA, CprB, Rent)
<-
    Total = 8 * Bid;
    Rent = Total * (CprA - CprB * Total) - W * Total.

+!adopt_central_bid(Round, Bid)
<-
    for(active_agent(A))
    {
        .send(A, achieve, adopt_central_bid(Round, Bid));
    }.

@central_bid_adoption_ack[atomic]
+central_bid_adopted(Round)[source(A)]
    : round(Round)
    & round_mode(Round, centralized)
    & active_agent(A)
    & not central_adoption_done(A, Round)
<-
    +central_adoption_done(A, Round);
    .count(central_adoption_done(_, Round), Count);
    .println("CENTRAL BID ACK ", A, " ROUND ", Round, " | ", Count, "/8");
    !check_central_adoption(Round, Count).

+!check_central_adoption(Round, 8)
    : not central_adoption_complete(Round)
<-
    +central_adoption_complete(Round);
    .println("ALL AGENTS ADOPTED CENTRAL BID FOR ROUND ", Round);
    for(round_finished_pending(A, Round))
    {
        !accept_central_round_finished(A, Round);
    }.

+!check_central_adoption(_, Count)
    : Count < 8
<-
    true.

@finish_non_centralized[atomic]
+round_finished(Round)[source(A)]
    : round(Round)
    & active_agent(A)
    & round_mode(Round, Mode)
    & Mode \== centralized
    & not finished(A, Round)
<-
    +finished(A, Round);

    .count(finished(_, Round), Count);
    !check_finished_count(Round, Count).

@finish_central_agent[atomic]
+round_finished(Round)[source(A)]
    : round(Round)
    & round_mode(Round, centralized)
    & active_agent(A)
    & not finished(A, Round)
<-
    +round_finished_pending(A, Round);
    !accept_central_round_finished(A, Round).

+!accept_central_round_finished(A, Round)
    : central_adoption_complete(Round)
    & round_finished_pending(A, Round)
    & not finished(A, Round)
<-
    -round_finished_pending(A, Round);
    !record_finished_agent(A, Round).

+!accept_central_round_finished(_, _)
<-
    true.

+!record_finished_agent(A, Round)
    : active_agent(A)
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

    for(central_bid_suggestion(A, Round, Bid, Strategy, Average))
    {
        -central_bid_suggestion(A, Round, Bid, Strategy, Average);
    };
    for(central_adoption_done(A, Round))
    {
        -central_adoption_done(A, Round);
    };
    for(round_finished_pending(A, Round))
    {
        -round_finished_pending(A, Round);
    };
    for(central_adoption_complete(Round))
    {
        -central_adoption_complete(Round);
    };
    for(round_mode(Round, Mode))
    {
        -round_mode(Round, Mode);
    };

    -round(Round);
    +round(NextRound);

    !start_round.

+!advance_round
    : round(Round)
    & max_rounds(Max)
    & Round >= Max
<-
    .println("SIMULATION FINISHED AFTER ", Round, " ROUNDS");
    .stopMAS(500).

+!apply_intervention(none)
<-
    -intervention(_);
    +intervention(no_intervention).

+!apply_intervention(coalition)
<-
   .println("APPLYING COALITION INTERVENTION");
   -intervention(_);
   +intervention(coalition).


+!apply_intervention(centralized)
<-
  .println("APPLYING CENTRALIZED INTERVENTION");
  -intervention(_);
  +intervention(centralized).

+!apply_intervention(decentralized)
<-
    .println("APPLYING DECENTRALIZED INTERVENTION");
    -intervention(_);
    +intervention(decentralized).
