/**
 * Name: assignment2_multiple_auctions
 * Based on the internal empty template.
 * Author: esther(Jingmeng)
 * Tags: Bonus1 of assignment2
 * Improvements: Enhanced GUI visualization
 */

model assignment2_multiple_auctions

global {
    int nb_bidders <- 10;
    int nb_auctioneers <- 3;
    int price_drop_interval <- 3;
    list<string> available_genres <- ["Clothes", "CDs", "Books", "Electronics"];
    
    init {
        create Bidder number: nb_bidders;
        create Auctioneer number: nb_auctioneers;
    }
}

species Bidder skills: [fipa] {
    string agentName <- name;
    float valuation <- 70.0 + rnd(50); // 70..120
    list<string> interested_genres <- [];
    map<string, bool> auction_participation <- map([]);
    
    // NEW: Track which auction this bidder is currently watching
    string current_auction <- nil;
    bool won_auction <- false;
    
    init {
        // Each bidder is interested in 1-3 random genres
        int num_interests <- 1 + rnd(2);
        loop times: num_interests {
            string genre <- one_of(available_genres);
            if !(genre in interested_genres) {
                add genre to: interested_genres;
            }
        }
        write name + " is interested in: " + interested_genres;
    }
    
    reflex react_to_cfps when: !empty(cfps) {
        loop incoming over: cfps {
            list msg <- incoming.contents;
            if (length(msg) >= 5 and msg[0] = "cfp") {
                string item <- string(msg[1]);
                string genre <- string(msg[2]);
                float offered_price <- float(msg[3]);
                string auction_id <- string(msg[4]);
                
                // Check if already won this specific auction
                if (auction_participation[auction_id] != nil and auction_participation[auction_id] = true) {
                    continue;
                }
                
                // Only participate if interested in the genre
                if (genre in interested_genres) {
                    current_auction <- auction_id; // Track participation
                    
                    if (offered_price <= valuation) {
                        write name + " proposing for " + item + " (" + genre + ") at price " + string(offered_price);
                        do propose message: incoming contents: ["propose", name, offered_price, auction_id];
                    }
                }
            }
        }
    }
    
    reflex on_accept when: !empty(accept_proposals) {
        loop a over: accept_proposals {
            list info <- a.contents;
            if (length(info) >= 5 and info[0] = "accept") {
                string auction_id <- string(info[4]);
                auction_participation[auction_id] <- true;
                won_auction <- true;
                write name + " WON " + info[1] + " (" + info[2] + ") at price " + string(info[3]);
            }
        }
    }
    
    reflex on_inform when: !empty(informs) {
        loop m over: informs {
            list info <- m.contents;
            if (length(info) >= 1) {
                if (info[0] = "CANCELLED") {
                    write name + " received CANCELLED for " + info[1];
                    current_auction <- nil;
                } else if (info[0] = "INFORM") {
                    current_auction <- nil;
                }
            }
        }
    }
    
    aspect default {
        // Color based on state
        rgb bidder_color <- #blue;
        if (won_auction) {
            bidder_color <- #gold; // Won an auction
        } else if (current_auction != nil) {
            bidder_color <- #orange; // Actively bidding
        }
        
        draw circle(3) color: bidder_color border: #black;
        
        // Display interested genres as text
        draw interested_genres[0] size: 2 color: #black at: location + {0, -5};
    }
}

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
    int proposal_count <- 0;
    
    init {
        genre <- one_of(available_genres);
        item_name <- genre + "_Item_" + string(rnd(100));
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
            to: list(Bidder) 
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
                    to: list(Bidder) 
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
                to: list(Bidder) 
                protocol: 'fipa-contract-net' 
                performative: 'inform' 
                contents: ["CANCELLED", item_name, genre, current_price, auction_id];
            
            active <- false;
            completed <- true;
        } else {
            write name + " lowers price: $" + string(old_price) + " → $" + string(current_price);
            
            do start_conversation 
                to: list(Bidder) 
                protocol: 'fipa-contract-net' 
                performative: 'cfp' 
                contents: ["cfp", item_name, genre, current_price, auction_id];
        }
    }
    
    aspect default {
        // Color based on genre
        rgb auction_color <- #gray;
        if (genre = "Clothes") {
            auction_color <- #red;
        } else if (genre = "CDs") {
            auction_color <- #purple;
        } else if (genre = "Books") {
            auction_color <- #green;
        } else if (genre = "Electronics") {
            auction_color <- #cyan;
        }
        
        // Change appearance based on status
        if (completed) {
            if (winner != nil) {
                draw square(6) color: auction_color border: #orange; // Sold
            } else {
                draw square(6) color: #gray border: #black; // Cancelled
            }
        } else if (active) {
            draw square(8) color: auction_color border: #yellow; // Active auction (larger, yellow border)
        } else {
            draw square(5) color: auction_color border: #black; // Not started yet
        }
        
        // Display item name and current price
        draw item_name size: 2.5 color: #black at: location + {0, 8};
        if (active) {
            draw "$" + string(int(current_price)) size: 3 color: #orange at: location + {0, -8};
        } else if (completed and winner != nil) {
            draw "SOLD" size: 2.5 color: #gold at: location + {0, -8};
        } else if (completed) {
            draw "CANCELLED" size: 2 color: #red at: location + {0, -8};
        }
    }
}

experiment main type: gui {
    output {
        display map type: 2d {
            species Auctioneer;
            species Bidder;
        }
        
        // NEW: Monitors to track auction progress
        monitor "Active Auctions" value: Auctioneer count (each.active);
        monitor "Completed Auctions" value: Auctioneer count (each.completed);
        monitor "Bidders with Wins" value: Bidder count (each.won_auction);
        monitor "Current Time" value: time;
        
    }
}