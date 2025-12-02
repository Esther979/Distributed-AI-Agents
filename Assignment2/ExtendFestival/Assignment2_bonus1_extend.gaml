/**
 * Name: assignment2_bonus1
 * Based on assignment1 festival code
 * Author: esther(Jingmeng)
 * Description: Assignment 2 Bonus 1- Extends festival with auction functionality
 * Guests attend auctions for festival items while managing hunger/thirst
 */

model assignment2_festival_auctions

global {
    // Original festival parameters
    int nb_guests <- 15;
    int nb_foodstores <- 3;
    int nb_drinkstores <- 3;
    int nb_infocenter <- 1;
    point location_infocenter <- {50, 50};
    int size_infocenter <- 5;
    float speed_guests <- 3.0;
    float hungerlevel <- 10.0;
    float thirstlevel <- 10.0;
    int world_dimension <- 100;
    
    // NEW: Auction parameters
    int nb_auctioneers <- 3;
    int price_drop_interval <- 3;
    list<string> available_genres <- ["FestivalTickets", "Merchandise", "FoodVouchers", "VIPPass"];
    
    init {
        create infoCenter number: nb_infocenter {
            location <- location_infocenter;
        }
        
        create foodStore number: nb_foodstores;
        create drinkStore number: nb_drinkstores;
        
        // NEW: Create auctioneers at different locations in the festival
        create Auctioneer number: nb_auctioneers;
        
        create guest number: nb_guests;
        
        loop counter from: 1 to: nb_guests {
            guest my_agent <- guest[counter - 1];
            my_agent <- my_agent.setName(counter);
        }
    }
}

// Extended guest species with auction capabilities
species guest skills: [moving, fipa] {
    // Original festival attributes
    float hunger <- 100.0;
    float thirst <- 100.0;
    string guestName <- "Undefined";
    float totalDistance <- 0.0;
    point last_location <- nil;
    float cooldown <- 0.0;
    point randomDestination <- nil;
    rgb color <- #green;
    stores target <- nil;
    bool headingToInfoCenter <- false;
    point infoCenterLocation <- location_infocenter;
    
    // NEW: Auction-related attributes
    float valuation <- 70.0 + rnd(50); // Budget for auction items: 70-120
    list<string> interested_genres <- [];
    map<string, bool> auction_participation <- map([]);
    string current_auction <- nil;
    bool won_auction <- false;
    bool attending_auction <- false;
    
    init {
        // Each guest is interested in 1-2 random auction genres
        int num_interests <- 1 + rnd(1);
        loop times: num_interests {
            string genre <- one_of(available_genres);
            if !(genre in interested_genres) {
                add genre to: interested_genres;
            }
        }
        write name + " interested in auctions: " + interested_genres;
    }
    
    action setName(int num) {
        guestName <- "Guest " + num;
    }
    
    // Track distance traveled
    reflex trackDistance {
        if last_location != nil {
            totalDistance <- totalDistance + (location distance_to last_location);
        }
        last_location <- location;
    }
    
    // NEW: React to auction calls for proposals
    reflex react_to_cfps when: !empty(cfps) and !attending_auction {
        loop incoming over: cfps {
            list msg <- incoming.contents;
            if (length(msg) >= 5 and msg[0] = "cfp") {
                string item <- string(msg[1]);
                string genre <- string(msg[2]);
                float offered_price <- float(msg[3]);
                string auction_id <- string(msg[4]);
                
                // Check if already won this auction
                if (auction_participation[auction_id] != nil and auction_participation[auction_id] = true) {
                    continue;
                }
                
                // Only participate if interested and basic needs are met
                if (genre in interested_genres and hunger > 30 and thirst > 30) {
                    current_auction <- auction_id;
                    attending_auction <- true;
                    
                    if (offered_price <= valuation) {
                        write guestName + " bidding on " + item + " (" + genre + ") at $" + string(offered_price);
                        do propose message: incoming contents: ["propose", name, offered_price, auction_id];
                    }
                }
            }
        }
    }
    
    // NEW: Handle auction acceptance
    reflex on_accept when: !empty(accept_proposals) {
        loop a over: accept_proposals {
            list info <- a.contents;
            if (length(info) >= 5 and info[0] = "accept") {
                string auction_id <- string(info[4]);
                auction_participation[auction_id] <- true;
                won_auction <- true;
                attending_auction <- false;
                write guestName + " WON " + info[1] + " (" + info[2] + ") at $" + string(info[3]);
            }
        }
    }
    
    // NEW: Handle auction completion/cancellation
    reflex on_inform when: !empty(informs) {
        loop m over: informs {
            list info <- m.contents;
            if (length(info) >= 1) {
                if (info[0] = "CANCELLED") {
                    write guestName + " - auction cancelled for " + info[1];
                    current_auction <- nil;
                    attending_auction <- false;
                } else if (info[0] = "INFORM") {
                    current_auction <- nil;
                    attending_auction <- false;
                }
            }
        }
    }
    
    // Original festival behavior: manage hunger/thirst
    reflex determineTarget when: target = nil and headingToInfoCenter = false and !attending_auction {
        if (cooldown > 0) {
            cooldown <- cooldown - 1;
            return;
        }
        
        hunger <- hunger - rnd(hungerlevel);
        thirst <- thirst - rnd(thirstlevel);
        
        if (hunger < 50 or thirst < 50) {
            randomDestination <- nil;
            headingToInfoCenter <- true;
            
            if (hunger <= thirst) {
                color <- #red;
            } else {
                color <- #blue;
            }
        }
    }
    
    // Move to info center when needs arise
    reflex moveToInfoCenter when: headingToInfoCenter = true and target = nil {
        do goto target: infoCenterLocation speed: speed_guests;
    }
    
    // Ask info center for directions
    reflex askInfoCenter when: headingToInfoCenter = true and target = nil {
        list<infoCenter> nearbyInfoCenters <- infoCenter at_distance size_infocenter;
        
        if (!empty(nearbyInfoCenters)) {
            string stateMessage <- guestName + ' arrived at Info Center, ';
            
            ask first(nearbyInfoCenters) {
                foodStore nearestFood <- foodStore closest_to myself;
                drinkStore nearestDrink <- drinkStore closest_to myself;
                
                if (myself.hunger <= myself.thirst) {
                    myself.target <- nearestFood;
                    stateMessage <- stateMessage + 'heading to ' + myself.target.name;
                } else {
                    myself.target <- nearestDrink;
                    stateMessage <- stateMessage + 'heading to ' + myself.target.name;
                }
            }
            
            write stateMessage;
            headingToInfoCenter <- false;
        }
    }
    
    // Normal wandering behavior
    reflex normalState when: target = nil and headingToInfoCenter = false and !attending_auction {
        if (randomDestination = nil or location distance_to randomDestination < 5) {
            randomDestination <- point(rnd(world_dimension), rnd(world_dimension));
        }
    }
    
    reflex wander when: target = nil and headingToInfoCenter = false and !attending_auction {
        if (randomDestination != nil) {
            do goto target: randomDestination speed: speed_guests;
        }
    }
    
    // Move to store
    reflex moveToTarget when: target != nil {
        do goto target: target.location speed: speed_guests;
    }
    
    // Arrive at store
    reflex arrivedStore when: target != nil and location distance_to(target.location) < 2.5 {
        ask target {
            if (sellsFood) {
                myself.hunger <- 100.0;
            }
            if (sellsDrink) {
                myself.thirst <- 100.0;
            }
        }
        
        color <- #green;
        cooldown <- 30.0;
        target <- nil;
        headingToInfoCenter <- false;
    }
    
    aspect default {
        // Color coding for guest state
        rgb guest_color <- #green;
        
        if (won_auction) {
            guest_color <- #gold; // Won an auction
        } else if (attending_auction or current_auction != nil) {
            guest_color <- #purple; // Participating in auction
        } else if (target != nil) {
            guest_color <- color; // Red (hungry) or Blue (thirsty)
        }
        
        draw circle(2) color: guest_color border: #black;
        
        // Show interested genre if participating in auction
        if (attending_auction and !empty(interested_genres)) {
            draw interested_genres[0] size: 1.5 color: #black at: location + {0, -4};
        }
    }
}

// Store species remain the same
species stores {
    bool sellsFood <- false;
    bool sellsDrink <- false;
}

species infoCenter parent: stores {
    list<foodStore> foodstores <- (foodStore at_distance 100);
    list<drinkStore> drinkstores <- (drinkStore at_distance 100);
    bool hasLocations <- false;
    
    reflex listStoreLocations when: hasLocations = false {
        ask foodStore {
            write "Food store at: " + location;
        }
        
        ask drinkStore {
            write "Drink store at: " + location;
        }
        
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

// NEW: Auctioneer species
species Auctioneer skills: [fipa] {
    string auction_id <- name;
    string item_name;
    string genre;
    float start_price;
    float current_price;
    float reserve_price;
    float decrease_step;
    float last_drop_time <- 0.0;
    bool active <- false;
    bool completed <- false;
    string winner <- nil;
    
    init {
        genre <- one_of(available_genres);
        item_name <- genre + "_" + string(rnd(100));
        start_price <- 150.0 + rnd(80);
        current_price <- start_price;
        reserve_price <- 70.0 + rnd(70);
        decrease_step <- 8.0 + rnd(9);
        
        write name + " will auction " + item_name + " (Genre: " + genre + ")";
        write "  Start: $" + string(start_price) + " | Reserve: $" + string(reserve_price);
    }
    
    reflex launch when: time = 1 and !active and !completed {
        write "\n=== " + name + " STARTS AUCTION ===";
        write "Item: " + item_name + " | Genre: " + genre;
        write "Starting price: $" + string(current_price);
        
        do start_conversation 
            to: list(guest) 
            protocol: 'fipa-contract-net' 
            performative: 'cfp' 
            contents: ["cfp", item_name, genre, current_price, auction_id];
        
        active <- true;
        last_drop_time <- time;
    }
    
    reflex handle_proposes when: active and !empty(proposes) {
        message p <- proposes[0];
        list info <- p.contents;
        
        if (length(info) >= 4 and info[0] = "propose") {
            float price_offered <- float(info[2]);
            string bidder_name <- string(info[1]);
            string prop_auction_id <- string(info[3]);
            
            if (prop_auction_id = auction_id) {
                write "\n*** " + name + " SOLD ***";
                write "Winner: " + bidder_name + " | Price: $" + string(price_offered);
                
                winner <- bidder_name;
                
                do accept_proposal 
                    message: p 
                    contents: ["accept", item_name, genre, price_offered, auction_id];
                
                do start_conversation 
                    to: list(guest) 
                    protocol: 'fipa-contract-net' 
                    performative: 'inform' 
                    contents: ["INFORM", "AUCTION_ENDED", item_name, "Winner: " + bidder_name, auction_id];
                
                active <- false;
                completed <- true;
            }
        }
    }
    
    reflex lower_price when: active and (time - last_drop_time) >= price_drop_interval and empty(proposes) {
        float old_price <- current_price;
        current_price <- current_price - decrease_step;
        last_drop_time <- time;
        
        if (current_price <= reserve_price) {
            write "\n*** " + name + " CANCELLED ***";
            write "Final price $" + string(current_price) + " below reserve $" + string(reserve_price);
            
            do start_conversation 
                to: list(guest) 
                protocol: 'fipa-contract-net' 
                performative: 'inform' 
                contents: ["CANCELLED", item_name, genre, current_price, auction_id];
            
            active <- false;
            completed <- true;
        } else {
            write name + " lowers price: $" + string(old_price) + " → $" + string(current_price);
            
            do start_conversation 
                to: list(guest) 
                protocol: 'fipa-contract-net' 
                performative: 'cfp' 
                contents: ["cfp", item_name, genre, current_price, auction_id];
        }
    }
    
    aspect default {
        // Color based on genre
        rgb auction_color <- #gray;
        if (genre = "FestivalTickets") {
            auction_color <- #red;
        } else if (genre = "Merchandise") {
            auction_color <- #purple;
        } else if (genre = "FoodVouchers") {
            auction_color <- #green;
        } else if (genre = "VIPPass") {
            auction_color <- #cyan;
        }
        
        // Visual indication of auction status
        if (completed) {
            if (winner != nil) {
                draw square(6) color: auction_color border: #orange; // Sold
            } else {
                draw square(6) color: #gray border: #black; // Cancelled
            }
        } else if (active) {
            draw square(8) color: auction_color border: #yellow; // Active
        } else {
            draw square(5) color: auction_color border: #black; // Not started
        }
        
        // Display information
        draw item_name size: 2 color: #black at: location + {0, 8};
        if (active) {
            draw "$" + string(int(current_price)) size: 2.5 color: #orange at: location + {0, -8};
        } else if (completed and winner != nil) {
            draw "SOLD" size: 2 color: #gold at: location + {0, -8};
        } else if (completed) {
            draw "CANCELLED" size: 1.5 color: #red at: location + {0, -8};
        }
    }
}

experiment main type: gui {
    output {
        display map type: opengl {
            species guest;
            species foodStore;
            species drinkStore;
            species infoCenter;
            species Auctioneer;
        }
        
        // Festival metrics
        monitor "Average Distance Traveled" value: mean(guest collect (each.totalDistance));
        monitor "Hungry Guests" value: guest count (each.hunger < 50);
        monitor "Thirsty Guests" value: guest count (each.thirst < 50);
        
        // Auction metrics
        monitor "Active Auctions" value: Auctioneer count (each.active);
        monitor "Completed Auctions" value: Auctioneer count (each.completed);
        monitor "Guests with Auction Wins" value: guest count (each.won_auction);
        monitor "Guests at Auctions" value: guest count (each.attending_auction);
        monitor "Current Time" value: time;
    }
}