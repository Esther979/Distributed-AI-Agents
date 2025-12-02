/**
* Name: Assignment2_Integrated
* Description: Merged model containing Festival logic (Ass1) and Advanced Auction logic (Ass2 Challenge 2)
* Author: Group7
*/

model Assignment2_Integrated

global {
    // --- Assignment 1 Global Variables ---
    int nb_guests <- 15;
    int nb_foodstores <- 3;
    int nb_drinkstores <- 3;
    int nb_infocenter <- 1;
    point location_infocenter <- {50,50};
    float speed_guests <- 2.0;
    float hungerlevel <- 2.0; // Reduced slightly to allow time for auctions
    float thirstlevel <- 2.0;
    int world_dimension <- 100;

    // --- Assignment 2 Global Variables ---
    int nb_auctioneers <- 1;
    // Switch between auction types
    string auction_type <- "Dutch" among: ["Dutch", "English", "Sealed"];
    // Stats
    float total_revenue <- 0.0;
    float total_bidder_gain <- 0.0;

    init {
        // 1. Create Festival Infrastructure (Ass1)
        create infoCenter number: nb_infocenter {
            location <- location_infocenter;
        }
        create foodStore number: nb_foodstores;
        create drinkStore number: nb_drinkstores;

        // 2. Create Auctioneers (Ass2)
        create Auctioneer number: nb_auctioneers {
            // Place auctioneer somewhere visible but not overlapping info center
            location <- {20, 80}; 
        }

        // 3. Create Guests (Merged Bidder + Guest)
        create guest number: nb_guests {
            // Initialize Ass1 name
            do setName(int(self));
        }
    }
}

// ============================================================
// SPECIES: STORES & INFO CENTER (From Assignment 1)
// ============================================================

species stores {
    bool sellsFood <- false;
    bool sellsDrink <- false;
}

species foodStore parent: stores {
    bool sellsFood <- true;
    aspect default {
        draw pyramid(5) at: location color: #brown;
    }
}

species drinkStore parent: stores {
    bool sellsDrink <- true;
    aspect default {
        draw pyramid(5) at: location color: #lightblue;
    }
}

species infoCenter parent: stores {
    list<foodStore> foodstores <- (foodStore at_distance 100);
    list<drinkStore> drinkstores <- (drinkStore at_distance 100);
    
    aspect default {
        draw sphere(3) at: location color: #orange;
    }
}

// ============================================================
// SPECIES: AUCTIONEER (From Assignment 2 Challenge 2)
// ============================================================

species Auctioneer skills: [fipa] {
    string item_name <- "Rare_Item";
    
    // Auction parameters
    float start_price <- 0.0;
    float current_price <- 0.0;
    float reserve_price <- 60.0;
    float decrease_step <- 10.0; // Dutch
    float increase_step <- 5.0;  // English
    
    // State variables
    bool active <- false;
    float last_action_time <- 0.0;
    int step_interval <- 2; 
    
    // Helper for English Auction
    list<agent> current_round_bidders <- [];
    agent highest_bidder <- nil;
    float highest_bid <- 0.0;

    init {
        reserve_price <- 60.0 + rnd(20);
        if (auction_type = "Dutch") {
            start_price <- 200.0 + rnd(50);
        } else if (auction_type = "English") {
            start_price <- reserve_price;
        } else {
            start_price <- 0.0;
        }
        current_price <- start_price;
        active <- false;
    }

    // --- START AUCTION ---
    reflex launch_auction when: time = 5 and !active { // Wait a bit (time=5) to let guests move
        active <- true;
        last_action_time <- time;
        
        write ">>> Auctioneer starts " + auction_type + " auction for " + item_name;
        
        if (auction_type = "Sealed") {
             do start_conversation to: list(guest) protocol: 'fipa-contract-net' performative: 'cfp' contents: ["cfp", item_name, 0.0];
        } else {
             write "Starting Price: " + current_price;
             do start_conversation to: list(guest) protocol: 'fipa-contract-net' performative: 'cfp' contents: ["cfp", item_name, current_price];
        }
    }

    // --- DUTCH LOGIC ---
    reflex process_dutch when: active and auction_type = "Dutch" and !empty(proposes) {
        message p <- proposes[0];
        list info <- p.contents;
        float price_sold <- float(info[2]);
        do accept_proposal message: p contents: ["accept", item_name, price_sold];
        total_revenue <- total_revenue + price_sold;
        
        if (length(proposes) > 1) {
            loop i from: 1 to: length(proposes) - 1 {
                do reject_proposal message: proposes[i] contents: ["reject", item_name];
            }
        }
        write "Dutch Auction Ended. Winner: " + agent(p.sender).name + " Price: " + price_sold;
        active <- false;
    }

    reflex decrease_dutch_price when: active and auction_type = "Dutch" and empty(proposes) and (time - last_action_time) >= step_interval {
        current_price <- current_price - decrease_step;
        last_action_time <- time;
        
        if (current_price < reserve_price) {
            write "Price below reserve. Cancelled.";
            do start_conversation to: list(guest) protocol: 'fipa-contract-net' performative: 'inform' contents: ["CANCELLED"];
            active <- false;
        } else {
            write "Lowering price to: " + current_price;
            do start_conversation to: list(guest) protocol: 'fipa-contract-net' performative: 'cfp' contents: ["cfp", item_name, current_price];
        }
    }

    // --- ENGLISH LOGIC ---
    reflex process_english_round when: active and auction_type = "English" and !empty(proposes) {
        current_round_bidders <- [];
        loop p over: proposes { add agent(p.sender) to: current_round_bidders; }
        
        highest_bidder <- current_round_bidders[rnd(length(current_round_bidders)-1)];
        highest_bid <- current_price;
        
        write string(length(current_round_bidders)) + " bidders accepted " + current_price + ". Increasing...";
        current_price <- current_price + increase_step;
        last_action_time <- time;
        
        loop p over: proposes { do reject_proposal message: p contents: ["continue"]; }
        do start_conversation to: list(guest) protocol: 'fipa-contract-net' performative: 'cfp' contents: ["cfp", item_name, current_price];
    }
    
    reflex close_english when: active and auction_type = "English" and empty(proposes) and (time - last_action_time) >= step_interval {
        if (highest_bidder != nil) {
            write "Sold to " + highest_bidder.name + " for " + highest_bid;
            do start_conversation to: [highest_bidder] protocol: 'fipa-contract-net' performative: 'accept_proposal' contents: ["accept", item_name, highest_bid];
            total_revenue <- total_revenue + highest_bid;
        } else {
            write "No bids. Cancelled.";
            do start_conversation to: list(guest) protocol: 'fipa-contract-net' performative: 'inform' contents: ["CANCELLED"];
        }
        active <- false;
    }

    // --- SEALED LOGIC ---
    reflex process_sealed when: active and auction_type = "Sealed" and (time - last_action_time) >= (step_interval * 2) {
        if (empty(proposes)) {
            write "No sealed bids.";
            active <- false;
        } else {
            message winning_msg <- nil;
            float max_bid <- 0.0;
            loop p over: proposes {
                list info <- p.contents;
                float bid_val <- float(info[2]);
                if (bid_val > max_bid) {
                    max_bid <- bid_val;
                    winning_msg <- p;
                }
            }
            if (winning_msg != nil and max_bid >= reserve_price) {
                do accept_proposal message: winning_msg contents: ["accept", item_name, max_bid];
                total_revenue <- total_revenue + max_bid;
                write "Sealed Won by " + agent(winning_msg.sender).name + " for " + max_bid;
                loop p over: proposes { if (p != winning_msg) { do reject_proposal message: p contents: ["reject"]; } }
            } else {
                write "Reserve not met. Cancelled.";
                 loop p over: proposes { do reject_proposal message: p contents: ["reject"]; }
            }
            active <- false;
        }
    }

    aspect default {
        draw square(5) color: active ? #red : #gray border: #black;
        draw auction_type color: #black size: 6 at: location + {0, -5};
    }
}

// ============================================================
// SPECIES: GUEST (Merged from Ass1 Guest + Ass2 Bidder)
// ============================================================

species guest skills: [moving, fipa] {
    // --- Ass1 Attributes ---
    float hunger <- 100.0;
    float thirst <- 100.0;
    string guestName <- "Undefined";
    point last_location <- nil;
    point randomDestination <- nil;
    rgb color <- #green;
    stores target <- nil;

    // --- Ass2 Attributes ---
    float valuation <- 70.0 + rnd(50);
    bool has_won <- false;

    action setName(int num) {
        guestName <- "Guest " + num; 
    }

    // Visuals: Prioritize Winning status > Hunger/Thirst
    aspect default {
        if (has_won) {
            draw circle(3) at: location color: #gold border: #black;
            draw "WINNER" color: #black size: 5 at: location + {0,5};
        } else {
            draw circle(2) at: location color: color border: #black;
        }
    }

    // --- ASS 1 LOGIC: Movement & Needs ---
    reflex determineTarget when: target = nil {
        hunger <- hunger - rnd(hungerlevel);
        thirst <- thirst - rnd(thirstlevel);
        
        if(hunger < 50 or thirst < 50){
            // Clear wandering target
            randomDestination <- nil;
            if(hunger <= thirst) {
                ask one_of(infoCenter) {
                    myself.target <- one_of(foodStore closest_to myself);
                    myself.color <- #red; // Hungry color
                }
            } else {
                ask one_of(infoCenter) {
                    myself.target <- one_of(drinkStore closest_to myself);
                    myself.color <- #blue; // Thirsty color
                }
            }
        }
    }
    
    reflex normalState when: target = nil {
        if (randomDestination = nil or location distance_to randomDestination < 5) {
            randomDestination <- point(rnd(world_dimension), rnd(world_dimension));
        }
        do goto target: randomDestination speed: speed_guests;
        if (!has_won) { color <- #green; }
    }
    
    reflex moveToTarget when: target != nil {
        do goto target: target.location speed: speed_guests;
    }
    
    reflex arrivedStore when: target != nil and location distance_to(target.location) < 2.5 {
        ask target {
            if(sellsFood) {
                myself.hunger <- 100.0;
                myself.color <- #green;
            } else if(sellsDrink) {
                myself.thirst <- 100.0;
                myself.color <- #green;
            }
        }
        target <- nil;
    }

    // --- ASS 2 LOGIC: Bidding ---
    // Note: FIPA messages are handled instantaneously, independent of movement state
    
    reflex react_to_cfps when: !empty(cfps) and !has_won {
        loop incoming over: cfps {
            list msg <- incoming.contents;
            if (length(msg) >= 3 and msg[0] = "cfp") {
                float offered_price <- float(msg[2]);
                
                if (auction_type = "Dutch") {
                    if (offered_price <= valuation) {
                        do propose message: incoming contents: ["propose", name, offered_price];
                        write name + " bids Dutch at " + offered_price;
                        break;
                    }
                } else if (auction_type = "English") {
                    if (offered_price <= valuation) {
                        do propose message: incoming contents: ["propose", name, offered_price];
                    }
                } else if (auction_type = "Sealed") {
                    do propose message: incoming contents: ["propose", name, valuation];
                }
            }
        }
    }

    reflex on_accept when: !empty(accept_proposals) {
        loop a over: accept_proposals {
            list info <- a.contents;
            if (length(info) >= 3 and info[0] = "accept") {
                has_won <- true;
                float pay_price <- float(info[2]);
                float my_gain <- valuation - pay_price;
                total_bidder_gain <- total_bidder_gain + my_gain;
                write name + " WON Item! Paid: " + pay_price + " Gain: " + my_gain;
            }
        }
    }

    reflex clear_mailboxes when: !empty(reject_proposals) or !empty(informs) {
        loop r over: reject_proposals { list d <- r.contents; }
        loop i over: informs { list d <- i.contents; }
    }
}

// ============================================================
// EXPERIMENT
// ============================================================

experiment Main type: gui {
    parameter "Auction Type" var: auction_type category: "Auction Settings";
    parameter "Number of Guests" var: nb_guests category: "Festival Settings";

    output {
        layout #split;
        
        display map type: opengl {
            species infoCenter;
            species foodStore;
            species drinkStore;
            species Auctioneer;
            species guest;
        }
        
        display "Auction Stats" {
            chart "Results" type: series {
                data "Auctioneer Revenue" value: total_revenue color: #red;
                data "Total Bidder Gain" value: total_bidder_gain color: #blue;
            }
        }
    }
}