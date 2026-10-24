// SHARED ROUND ENGINE — use this template for each communication scenario.
// The communication logic lives in agents; the planner never imposes a bid.
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
endowment(10).
market1_return(5).
cpr_a(23).
cpr_b(0.25).

!start.

+!start <-
    !start_round.

+!start_round
    : round(Round) & run_id(RunId) & seed(Seed)
<-
    .println("STARTING ROUND ", Round, " SEED ", Seed);
    for(active_agent(A)) {
        .send(A, tell, start_round(RunId, Round, Seed));
    }.

@submit_bid[atomic]
+!submit_bid(Round, Bid, Strategy)[source(A)]
    : round(Round)
    & active_agent(A)
    & Bid >= 0 & Bid <= 10
    & not bid(A, Round, _)
<-
    +bid(A, Round, Bid);
    +played_strategy(A, Round, Strategy);
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
    & cpr_a(A)
    & cpr_b(B)
    & seed(Seed)
    & run_id(RunId)
<-
    Total = B1+B2+B3+B4+B5+B6+B7+B8;
    Average = Total / 8;
    Rent = Total * (A - B * Total) - W * Total;
    OptimalTotal = (A - W) / (2 * B);
    OptimalRent = OptimalTotal * (A - B * OptimalTotal) - W * OptimalTotal;
    RentPct = 100 * Rent / OptimalRent;
    results.append("results/coalition_strat/rounds.csv",
                   RunId, Seed, Round, Total, Average, Rent, RentPct);
    !calculate_returns(Round, Total, Average).

+!calculate_returns(Round, Total, Average)
<-
    for(bid(A, Round, Bid)
        & played_strategy(A, Round, Strategy)
        & endowment(E)
        & market1_return(W)
        & cpr_a(CprA)
        & cpr_b(CprB)
        & run_id(RunId)
        & seed(Seed)) {
        Market1 = W * (E - Bid);
        Market2 = Bid * (CprA - CprB * Total);
        Payoff = Market1 + Market2;
        results.append("results/coalition_strat/agents.csv",
                       RunId, Seed, Round, A, Strategy, Bid,
                       Market1, Market2, Payoff);
        .send(A, achieve,
              round_result(Round, Bid, Total, Average, Market1, Market2, Payoff));
    }.

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
    : round(Round)
    & not round_advanced(Round)
<-
    +round_advanced(Round);
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
    Next = Round + 1;
    -round(Round);
    +round(Next);
    !start_round.

+!advance_round
    : round(Round)
    & max_rounds(Max)
    & Round >= Max
<-
    .println("SIMULATION FINISHED ", Round, " ROUNDS");
    .stopMAS(500).
