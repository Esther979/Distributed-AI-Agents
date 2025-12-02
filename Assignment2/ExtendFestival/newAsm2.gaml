/**
* Name: FestivalWithAuction
* Description: Merged model of Festival (Task 1) and Dutch Auction (Task 2)
* Author: xiao
*/

model FestivalWithAuction

global {
    // --- Festival Parameters ---
    int nb_guests <- 15;
    int nb_foodstores <- 3;
    int nb_drinkstores <- 3;
    int nb_infocenter <- 1;
    point location_infocenter <- {50,50};
    int size_infocenter <- 5;
    float speed_guests <- 3.0;
    float hungerlevel <- 10.0;
    float thirstlevel <- 10.0;
    int world_dimension <- 100;

    // --- Auction Parameters ---
    int nb_auctioneers <- 1;
    int price_drop_interval <- 50; // Increased interval slightly so guests have time to move

    init {
        // 1. Create Festival Environment
        create infoCenter number: nb_infocenter {
            location <- location_infocenter;
        }
        create foodStore number: nb_foodstores;
        create drinkStore number: nb_drinkstores;

        // 2. Create Guests (Who are also Bidders)
        create guest number: nb_guests;
        
        // Loop to name guests
        loop counter from: 1 to: nb_guests {
            guest my_agent <- guest[counter - 1];
            ask my_agent {
                do setName(counter);
            }
        }
        

        // 3. Create Auctioneer
        create Auctioneer number: nb_auctioneers {
            // Place auctioneer randomly or at a fixed location
            location <- {80, 80}; 
        }
    }
}

/* * GUEST SPECIES
 * Combines movement/eating logic AND FIPA bidding logic 
 */
species guest skills: [moving, fipa] {
    
    // --- Festival Attributes ---
    float hunger <- 100.0;
    float thirst <- 100.0;
    string guestName <- "Undefined";
    point randomDestination <- nil;
    rgb color <- #green;
    stores target <- nil;

    // --- Auction Attributes ---
    float valuation <- 70.0 + rnd(50); // 70..120
    bool has_won <- false;

    action setName(int num) {
        guestName <- "Guest " + num; 
        // Ensure the agent name used by FIPA matches or is identifiable
        // built-in 'name' variable is usually sufficient for FIPA
    }
    
    aspect default {
        draw circle(2) at: location color: color;
        // Optional: visualize if they won
        if (has_won) {
            draw "WINNER" at: location + {0, -3} color: #black size: 10;
        }
    }
    
    // --- FESTIVAL BEHAVIORS (Movement & Needs) ---
    
    reflex determineTarget when: target = nil {
        hunger <- hunger - rnd(hungerlevel);
        thirst <- thirst - rnd(thirstlevel);
        
        if(hunger < 50 or thirst < 50){
            string stateMessage <- guestName;
            randomDestination <- nil; 
            
            if(hunger <= thirst) {
                // stateMessage <- guestName + ' is hungry, ';
                ask one_of(infoCenter) {
                    myself.target <- one_of(foodStore closest_to myself);
                    myself.color <- #red;
                }
            } else {
                // stateMessage <- guestName + ' is thirsty, ';
                ask one_of(infoCenter) {
                    myself.target <- one_of(drinkStore closest_to myself);
                    myself.color <- #blue;
                }
            }
        }
    }
    
    reflex normalState when: target = nil {
        if (randomDestination = nil or location distance_to randomDestination < 5) {
            randomDestination <- point(rnd(world_dimension), rnd(world_dimension));
        }
        do goto target: randomDestination speed: speed_guests;
        if (!has_won) { color <- #green; } // Keep green only if not a winner (optional logic)
    }
    
    reflex moveToTarget when: target != nil {
        do goto target: target.location speed: speed_guests;
    }
    
    reflex arrivedStore when: target != nil and location distance_to(target.location) < 2.5 {
        ask target {
            string getFood <- myself.name;
            if(sellsFood = true) {
                myself.hunger <- 100.0;
                myself.target <- nil;
                myself.color <- #green;
                getFood <- getFood + ' ate food at ' + name;
            } else if(sellsDrink = true) {
                myself.thirst <- 100.0;
                myself.target <- nil;
                myself.color <- #green;
                getFood <- getFood + ' had drink at ' + name;
            }
            // write getFood; // Reducing console spam
        }
        target <- nil;
    }

    // --- AUCTION BEHAVIORS (FIPA) ---

    // Respond to Call for Proposal (CFP)
    reflex react_to_cfps when: !empty(cfps) and !has_won {
        loop incoming over: cfps {
            list msg <- incoming.contents;
            // Expecting contents: ["cfp", item_name, price]
            if (length(msg) >= 3 and msg[0] = "cfp") {
                float offered_price <- float(msg[2]);
                
                // Logic: Only propose if price is good AND not starving (optional complexity)
                if (offered_price <= valuation) {
                    write guestName + " bids for item at " + offered_price;
                    do propose message: incoming contents: ["propose", guestName, offered_price];
                    break;
                }
            }
        }
    }

    // Handle Winning
    reflex on_accept when: !empty(accept_proposals) {
        loop a over: accept_proposals {
            list info <- a.contents;
            if (length(info) >= 3 and info[0] = "accept") {
                has_won <- true;
                color <- #gold; // Visual feedback for winner
                write guestName + " WON " + info[1] + " at price " + string(info[2]);
            }
        }
    }

    // Handle Information (Auction Cancelled or Ended)
    reflex on_inform when: !empty(informs) {
        loop m over: informs {
            list info <- m.contents;
            if (length(info) >= 1 and info[0] = "CANCELLED") {
                // write guestName + " knows auction is cancelled.";
            }
        }
    }
}

/* * AUCTIONEER SPECIES
 * Implements the Dutch Auction logic
 */
species Auctioneer skills: [fipa] {
    string item_name <- "Rare_Item";
    float start_price <- 200.0;
    float current_price <- 200.0;
    float reserve_price <- 60.0;
    float decrease_step <- 10.0;
    float last_drop_time <- 0.0;
    bool active <- false;

    init {
        start_price <- 150.0 + rnd(80); 
        current_price <- start_price;
        reserve_price <- 70.0 + rnd(70); 
        decrease_step <- 8.0 + rnd(9); 
        last_drop_time <- 0.0;
        active <- false;
    }

    // Start auction shortly after simulation begins
    reflex launch when: time = 10 and !active {
        write name + " starts Dutch auction for " + item_name + " at price " + string(current_price);
        // TARGET: Send to list(guest) instead of list(Bidder)
        do start_conversation to: list(guest) protocol: 'fipa-contract-net' performative: 'cfp' contents: ["cfp", item_name, current_price];
        active <- true;
        last_drop_time <- time;
    }

    // Handle proposals (Guest buys the item)
    reflex handle_proposes when: active and !empty(proposes) {
        message p <- proposes[0];
        list info <- p.contents; 
        if (length(info) >= 3 and info[0] = "propose") {
            float price_offered <- float(info[2]);
            string bidder_name <- string(info[1]);

            write name + " accepts proposal from " + bidder_name + " at price " + string(price_offered);

            do accept_proposal message: p contents: ["accept", item_name, price_offered];

            // Inform everyone auction ended
            do start_conversation
            to: list(guest)
            protocol: 'fipa-contract-net' 
            performative: 'inform'
            contents: ["INFORM", "AUCTION_ENDED", item_name, "Winner: " + bidder_name];
            
            active <- false; 
        } 
    }

    // Decrease price over time
    reflex lower_price when: active and (time - last_drop_time) >= price_drop_interval and empty(proposes) {
        float old_price <- current_price;
        current_price <- current_price - decrease_step;
        last_drop_time <- time;

        if (current_price <= reserve_price) {
            write name + " cancels auction (Reserve Price Reached)";
            do start_conversation 
            to: list(guest) 
            protocol: 'fipa-contract-net' 
            performative: 'inform' 
            contents: ["CANCELLED", item_name, current_price];
            active <- false;
        } else {
            write name + " lowers price to " + string(current_price);
            do start_conversation
            to: list(guest)
            protocol: 'fipa-contract-net'
            performative: 'cfp'
            contents: ["cfp", item_name, current_price]; 
        }
    }

    aspect default {
        draw square(4) at: location color: #purple border: #black;
        draw "Auction" at: location + {0, -4} color: #purple size: 10;
    }
}
    
// --- EXISTING FESTIVAL STORES (UNCHANGED) ---

species stores {
    bool sellsFood <- false;
    bool sellsDrink <- false;
}
    
species infoCenter parent: stores {
    list<foodStore> foodstores <- (foodStore at_distance 100);
    list<drinkStore> drinkstores <- (drinkStore at_distance 100);
    bool hasLocations <- false;
    
    reflex listStoreLocations when: hasLocations = false {
        // Just keeping logic, removed print to reduce noise
        hasLocations <- true;
    }
    
    aspect default {
        draw sphere(3) at: location color: #orange;
    }
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

// --- EXPERIMENT ---

experiment main type: gui {
    output {
        display map type: opengl {
            species foodStore;
            species drinkStore;
            species infoCenter;
            species Auctioneer; // Added Auctioneer to display
            species guest;
        }
    }
}