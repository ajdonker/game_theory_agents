round(1).
max_rounds(5).

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
//starting goals
!start.
// plans
+!start <- 
    .println("STARTING SIM");
    !start_round.


+!start_round
    : round(Round)
<-
    .println("");
    .println("===============");
    .println("STARTING ROUND: ", Round);
    .println("===============");

    //.broadcast(tell, start_round(Round)).

    for(active_agent(A))
    {
        .send(A, tell, start_round(Round));
    }
    .println("").



@submit_bid[atomic] // otherwise race condition triggers mutliple recalcs of round
+!submit_bid(Round, Bid)[source(Requester)]
    : round(Round)
    & Bid >= 0
    & Bid <= 10
<-
    +bid(Requester, Round, Bid);

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
<-
    Total = B1+B2+B3+B4+B5+B6+B7+B8;
    Average = Total / 8;

    .println(
        "TOTAL MARKET 2 INVESTMENT: ", Total,
        " | GROUP AVERAGE: ", Average
    );

    !calculate_returns(Round, Total, Average).

+!calculate_returns(Round, Total, Average)
<-
    for (
        bid(A, Round, Bid)
        & endowment(E)
        & market1_return(W)
        & cpr_a(CprA)
        & cpr_b(CprB)
    ) {
        Market1 = W * (E - Bid);
        Market2 = Bid * (CprA - CprB * Total);
        Payoff = Market1 + Market2;

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

+!advance_round
    : round(Round)
    & max_rounds(MaxRounds)
    & Round < MaxRounds 
<- 
    NextRound = Round + 1;

    -round(Round);
    +round(NextRound);

    !start_round.

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

    !start_round.

+!advance_round
    : round(Round)
    & max_rounds(Max)
    & Round >= Max
<-
    .println("SIMULATION FINISHED AFTER ", Round, " ROUNDS").