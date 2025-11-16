/**
* Name: assignment2
* Based on the internal empty template. 
* Author: xiao
* Tags: 
*/


model assignment2

/* Insert your model definition here */


global {
    int nb_bidders <- 10;
    int nb_auctioneers <- 1;
    int price_drop_interval <- 3; // number of ticks between price decreases

    init {
        create Bidder number: nb_bidders;
        create Auctioneer number: nb_auctioneers;
    }
}

species Bidder skills: [fipa] {
    string agentName <- name;
    float valuation <- 70.0 + rnd(50); // 70..120
    bool has_won <- false;

    reflex react_to_cfps when: !empty(cfps) and !has_won {
        loop incoming over: cfps {
            list msg <- incoming.contents;
            // Expecting contents: ["cfp", item_name, price]
            if (length(msg) >= 3 and msg[0] = "cfp") {
                float offered_price <- float(msg[2]);
                if (offered_price <= valuation) {
                    // Propose to buy at the offered price
                    do propose message: incoming contents: ["propose", name, offered_price];
                    // After proposing once, stop processing other CFPS in this reflex
                    break;
                }
            }
        }
    }

    reflex on_accept when: !empty(accept_proposals) {
        loop a over: accept_proposals {
            list info <- a.contents;
            // Expect accept_proposal to contain: ["accept", item_name, price]
            if (length(info) >= 3 and info[0] = "accept") {
                has_won <- true;
                write name + " WON " + info[1] + " at price " + string(info[2]);
            }
        }
    }

    reflex on_inform when: !empty(informs) {
        loop m over: informs {
            // Handle cancellation or other informs from auctioneer
            list info <- m.contents;
            if (length(info) >= 1 and info[0] = "CANCELLED") {
                // Nothing special to do, just acknowledge
                write name + " received CANCELLED from " + string(agent(m.sender).name);
            }
        }
    }

    aspect default {
        draw circle(3) color: rgb("blue");
    }
}

// Auctioneer species: implements a Dutch auction
species Auctioneer skills: [fipa] {
    string item_name <- "Rare_Item";
    float start_price <- 200.0;
    float current_price <- 200.0;
    float reserve_price <- 60.0;
    float decrease_step <- 10.0;
    float last_drop_time <- 0.0;
    bool active <- false;

    // initialize auctioneer parameters randomly for variation
    init {
        start_price <- 150.0 + rnd(80); // 150..230
        current_price <- start_price;
        reserve_price <- 70.0 + rnd(70); // 70..140
        decrease_step <- 8.0 + rnd(9); // 8..17
        last_drop_time <- 0.0;
        active <- false;
    }

    reflex launch when: time = 1 and !active {
        write name + " starts Dutch auction for " + item_name + " at price " + string(current_price);
        // Use FIPA CFP to broadcast starting price to all bidders
        do start_conversation to: list(Bidder) protocol: 'fipa-contract-net' performative: 'cfp' contents: ["cfp", item_name, current_price];
        active <- true;
        last_drop_time <- time;
    }

    // If any bidder proposes, accept the first propose
    reflex handle_proposes when: active and !empty(proposes) {
        message p <- proposes[0];
        list info <- p.contents; 
        if (length(info) >= 3 and info[0] = "propose") {
            float price_offered <- float(info[2]);
            string bidder_name <- string(info[1]);

            write name + " accepts proposal from " + bidder_name + " at price " + string(price_offered);

            // Accept the proposal
            do accept_proposal message: p contents: ["accept", item_name, price_offered];

            // inform auction ended
            do start_conversation
		    to: list(Bidder)
		    protocol: 'fipa-contract-net' 
		    performative: 'inform'
		    contents: ["INFORM", "AUCTION_ENDED", item_name, "Winner: " + bidder_name];
            // end
            active <- false; 

        
        } else {
            write name + " received unexpected propose format: " + string(info);
        }
    }

    // If no proposals for a while, lower the price; cancel if below reserve
    reflex lower_price when: active and (time - last_drop_time) >= price_drop_interval and empty(proposes) {
        float old_price <- current_price;
        current_price <- current_price - decrease_step;
        last_drop_time <- time;

        if (current_price <= reserve_price) {
            write name + " cancels auction for " + item_name + " (price " + string(current_price) + " <= reserve " + string(reserve_price) + ")";
            // Notify bidders about cancellation
            do start_conversation 
		    to: list(Bidder) 
		    protocol: 'fipa-contract-net' // 保持与 CFP 一致
		    performative: 'inform' 
		    contents: ["CANCELLED", item_name, current_price];
		    active <- false;
        } else {
            write name + " lowers price from " + string(old_price) + " to " + string(current_price);
            // Broadcast new price using CFP
            do start_conversation
		    to: list(Bidder)
		    protocol: 'fipa-contract-net'
		    performative: 'cfp'
		    contents: ["cfp", item_name, current_price]; 
            
        }
    }

    aspect default {
        draw square(4) color: rgb("red");
    }
}

// Experiment and display
experiment main type: gui {
    output {
        display map type: opengl {
            species Bidder;
            species Auctioneer;
        }
    }
}
