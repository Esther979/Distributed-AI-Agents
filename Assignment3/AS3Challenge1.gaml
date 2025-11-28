/**
* Name: Assignment3_Challenge1
* Description: Global Utility Optimization with Crowd Mass
* Author: Group7
*/

model FestivalChallenge

global {
    int number_of_stages <- 4;
    int number_of_guests <- 20;
    
    // Global utility for chart
    float current_global_utility <- 0.0;
    bool optimization_done <- false;
    
    init {
        // Create Stages
        create stage number: number_of_stages {
            location <- {rnd(10, 90), rnd(10, 90)};
            val_light_show <- rnd(1.0);
            val_speaker <- rnd(1.0);
            val_music_style <- rnd(1.0);
            color <- rgb(val_light_show*255, val_speaker*255, val_music_style*255);
        }

        // Create Guests
        create guest number: number_of_guests {
            location <- {rnd(40, 60), rnd(40, 60)};
            pref_light_show <- rnd(1.0);
            pref_speaker <- rnd(1.0);
            pref_music_style <- rnd(1.0);
            // Challenge 1: Crowd preference
            pref_crowd_mass <- rnd(1.0);
        }
        
        // Create Leader
        create Leader number: 1 {
            location <- {50, 50};
        }
    }
}

species stage skills: [fipa] {
    float val_light_show;
    float val_speaker;
    float val_music_style;
    rgb color;
    
    int assigned_guests_count <- 0;

    aspect default {
        draw square(6) color: color border: #black;
        draw "Stage " + int(self) color: #black size: 4 at: location + {0, -5};
        draw "Guests: " + assigned_guests_count color: #black size: 4 at: location + {0, -8};
    }

    // Reply to guests asking for attributes
    reflex reply_to_guest when: !empty(mailbox) {
        loop msg over: mailbox {
            list<unknown> content <- list<unknown>(msg.contents);
            if (content[0] = "ask_attributes") {
                do start_conversation to: [msg.sender] 
                                      protocol: 'fipa-request' 
                                      performative: 'inform' 
                                      contents: ["stage_info", val_light_show, val_speaker, val_music_style];
            }
            // Important: Do not manually clear mailbox with assignment. 
            // The loop doesn't auto-remove, so we should be careful. 
            // But in FIPA skill, reading doesn't always remove. 
            // Best practice: read and ignore or let GAMA handle cycle cleanup if using fipa skill properly.
            // Here we explicitly consume the message by doing nothing else.
        }
        // FIX: Do NOT use "mailbox <- [];" This causes the casting error.
        // Instead, we can use "do end_conversation message: msg;" inside loop or just let it be if using no-protocol carefully.
        // For simplicity in this script, we just iterate. GAMA usually clears processed messages in next cycle if not stored.
        // To be safe and fix the error, we will rely on standard FIPA consumption.
    }
}

species guest skills: [fipa, moving] {
    float pref_light_show;
    float pref_speaker;
    float pref_music_style;
    float pref_crowd_mass; 

    bool info_collected <- false;
    bool sent_to_leader <- false;
    stage target_stage <- nil;
    
    // Using a list to store utilities because map keys with agents can sometimes be tricky in deep copies
    // But map is fine here.
    map<stage, float> base_utilities; 

    aspect default {
        draw circle(1.5) color: (target_stage != nil) ? #green : #red border: #black;
    }

    // Step 1: Ask all stages for info
    reflex ask_stages when: !info_collected and empty(base_utilities) {
        do start_conversation to: list(stage) 
                              protocol: 'fipa-request' 
                              performative: 'request' 
                              contents: ["ask_attributes"];
    }

    // Step 2: Collect info
    reflex collect_info when: !info_collected and !empty(mailbox) {
        loop msg over: mailbox {
            list<unknown> content <- list<unknown>(msg.contents);
            if (content[0] = "stage_info") {
                stage s <- stage(msg.sender);
                float u <- (pref_light_show * float(content[1])) + 
                           (pref_speaker * float(content[2])) + 
                           (pref_music_style * float(content[3]));
                add u at: s to: base_utilities;
            }
        }
        
        if (length(base_utilities) = number_of_stages) {
            info_collected <- true;
        }
    }

    // Step 3: Send preferences to Leader
    reflex send_pref_to_leader when: info_collected and !sent_to_leader {
        do start_conversation to: list(Leader) 
                              protocol: 'fipa-request' 
                              performative: 'inform' 
                              contents: ["my_preferences", base_utilities, pref_crowd_mass];
        sent_to_leader <- true;
        // write name + " sent preferences to Leader.";
    }

    // Step 4: Receive order from Leader
    reflex receive_order when: sent_to_leader and !empty(mailbox) {
        loop msg over: mailbox {
            list<unknown> content <- list<unknown>(msg.contents);
            if (content[0] = "move_order") {
                target_stage <- stage(content[1]);
                write name + " received order to go to " + target_stage;
            }
        }
    }

    reflex move when: target_stage != nil {
        do goto target: target_stage speed: 2.0;
    }
}

species Leader skills: [fipa] {
    map<guest, list> all_guest_data;
    map<guest, stage> current_assignment;
    
    bool optimizing <- false;
    int optimization_step <- 0;
    int max_optimization_steps <- 200; 

    aspect default {
        draw triangle(6) color: #blue border: #black;
        draw "LEADER" color: #blue at: location + {0, 5};
    }

    // Collect Data
    reflex collect_guest_data when: !optimizing and length(all_guest_data) < number_of_guests {
        if (!empty(mailbox)) {
            loop msg over: mailbox {
                list<unknown> content <- list<unknown>(msg.contents);
                if (content[0] = "my_preferences") {
                    guest g <- guest(msg.sender);
                    add [content[1], content[2]] at: g to: all_guest_data;
                }
            }
        }
        
        if (length(all_guest_data) = number_of_guests) {
            write "Leader: All data collected. Starting Optimization...";
            optimizing <- true;
            do initial_random_assignment;
        }
    }

    action initial_random_assignment {
        loop g over: all_guest_data.keys {
            add list(stage)[rnd(number_of_stages - 1)] at: g to: current_assignment;
        }
        current_global_utility <- calculate_global_utility(current_assignment);
    }

    // Optimization Loop
    reflex optimize_allocation when: optimizing and optimization_step < max_optimization_steps {
        optimization_step <- optimization_step + 1;
        
        // Try swapping a random guest to a random stage
        guest random_guest <- one_of(current_assignment.keys);
        stage current_stage <- current_assignment[random_guest];
        stage new_stage <- one_of(list(stage) - current_stage);
        
        current_assignment[random_guest] <- new_stage;
        
        float new_utility <- calculate_global_utility(current_assignment);
        
        if (new_utility > current_global_utility) {
            current_global_utility <- new_utility;
        } else {
            // Revert
            current_assignment[random_guest] <- current_stage;
        }
        
        if (optimization_step = max_optimization_steps) {
            do finalize_and_send_orders;
        }
    }

    float calculate_global_utility(map<guest, stage> assignments) {
        float total_utility <- 0.0;
        
        // Count guests per stage
        map<stage, int> stage_counts;
        loop s over: list(stage) { stage_counts[s] <- 0; }
        loop g over: assignments.keys {
            stage s <- assignments[g];
            stage_counts[s] <- stage_counts[s] + 1;
        }
        
        // Sum utilities
        loop g over: assignments.keys {
            stage s <- assignments[g];
            list data <- all_guest_data[g];
            map<stage, float> base_utils <- data[0];
            float crowd_pref <- float(data[1]);
            
            float base_u <- base_utils[s];
            float crowd_factor <- stage_counts[s] / number_of_guests;
            
            // Calculate crowd satisfaction: closer to pref is better
            float crowd_satisfaction <- 1.0 - abs(crowd_pref - crowd_factor);
            
            total_utility <- total_utility + (base_u + crowd_satisfaction);
        }
        return total_utility;
    }

    action finalize_and_send_orders {
        write "Optimization Finished. Final Global Utility: " + current_global_utility;
        optimization_done <- true;
        
        // Update stage counts for display
        loop s over: list(stage) { s.assigned_guests_count <- 0; }
        
        loop g over: current_assignment.keys {
            stage target <- current_assignment[g];
            target.assigned_guests_count <- target.assigned_guests_count + 1;
            
            do start_conversation to: [g] 
                                  protocol: 'fipa-request' 
                                  performative: 'inform' 
                                  contents: ["move_order", target];
        }
    }
}

experiment Main type: gui {
    output {
        layout #split;
        
        display Map type: java2D {
            species stage aspect: default;
            species guest aspect: default;
            species Leader aspect: default;
        }
        
        display "Global Utility Chart" {
            chart "Global Utility Optimization" type: series {
                data "Global Utility" value: current_global_utility color: #blue;
            }
        }
    }
}