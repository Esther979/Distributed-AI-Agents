/**
* Name: Final Project - Challenge 2: Reinforcement Learning
* Author: Chang
* Description: Implementation of Challenge 2 where agents learn from experience using Q-Learning.
*/

model SocialInteractionRL

global {
    int nb_guests <- 60;
    int nb_bars <- 2;
    int nb_concerts <- 1;
    int nb_cafes <- 2;
    int nb_clubs <- 1;

    list<Place> all_places <- [];
    
    // Global Stats
    float global_happiness <- 0.5;
    float global_social_energy <- 0.5;
    int total_positive_interactions <- 0;
    int total_negative_interactions <- 0;
    int total_friendships_formed <- 0;

    // History for charts
    list<float> happiness_history <- [];
    list<int> interaction_history <- [];
    
    // --- RL Metrics for Visualization ---
    // We want to track how different types rate the "Club" over time to prove learning
    float avg_introvert_q_club <- 0.0;
    float avg_party_q_club <- 0.0;

    geometry shape <- square(100);

    init {
        write "Simulation initializing with Reinforcement Learning...";
        create Bar number: nb_bars;
        create Concert number: nb_concerts;
        create Cafe number: nb_cafes;
        create Club number: nb_clubs;

        all_places <- Bar + Concert + Cafe + Club;

        create PartyPerson number: 12;
        create IntrovertPerson number: 12;
        create MusicLover number: 12;
        create HealthEnthusiast number: 12;
        create SocialButterfly number: 12;

        write "Agents created. Starting simulation...";
        do update_global_stats;
    }

    action update_global_stats {
        list<Guest> all_guests <- PartyPerson + IntrovertPerson + MusicLover + HealthEnthusiast + SocialButterfly;
        
        if (length(all_guests) > 0) {
            global_happiness <- mean(all_guests collect each.happiness);
            global_social_energy <- mean(all_guests collect each.social_energy);
            
            // --- RL Visualization Data Collection ---
            // Calculate average Q-value for "club" for Introverts vs Party People
            // This demonstrates Requirement: "improvement in agents behavior" 
            list<IntrovertPerson> introverts <- list(IntrovertPerson);
            if (!empty(introverts)) {
                avg_introvert_q_club <- mean(introverts collect (each.q_values["club"]));
            }
            
            list<PartyPerson> party_people <- list(PartyPerson);
            if (!empty(party_people)) {
                avg_party_q_club <- mean(party_people collect (each.q_values["club"]));
            }
        }

        happiness_history << global_happiness;
        interaction_history << (total_positive_interactions - total_negative_interactions);

        if (length(happiness_history) > 200) {
            remove index: 0 from: happiness_history;
            remove index: 0 from: interaction_history;
        }
    }

    reflex update_stats when: every(10 #cycles) {
        do update_global_stats;
    }
}

// --- Type of place ---
species Place {
    rgb color;
    float noise_level;
    string place_type;
    list<Guest> current_guests <- [];
    float radius <- 12.0;
    geometry shape <- circle(radius);

    reflex update_occupancy {
        current_guests <- (PartyPerson + IntrovertPerson + MusicLover + HealthEnthusiast + SocialButterfly) inside shape;
    }

    aspect default {
        draw shape color: color border: #black;
        draw place_type + " (" + length(current_guests) + ")" color: #black at: location - {2,0} font: font("Arial", 12, #bold);
    }
}

species Bar parent: Place {
    init { color <- #red; noise_level <- 0.7; place_type <- "bar"; location <- {rnd(15,85), rnd(15,85)}; }
}
species Concert parent: Place {
    init { color <- #purple; noise_level <- 0.9; place_type <- "concert"; location <- {rnd(15,85), rnd(15,85)}; }
}
species Cafe parent: Place {
    init { color <- #brown; noise_level <- 0.3; place_type <- "cafe"; location <- {rnd(15,85), rnd(15,85)}; }
}
species Club parent: Place {
    init { color <- #pink; noise_level <- 0.95; place_type <- "club"; location <- {rnd(15,85), rnd(15,85)}; }
}

// --- Guest (With RL Brain) ---
species Guest skills: [fipa, moving] {
    // Traits
    float extroversion <- rnd(1.0);
    float generosity <- rnd(1.0);
    float music_preference <- rnd(1.0);
    float health_consciousness <- rnd(1.0);

    float happiness <- 0.5;
    float social_energy <- 0.5;
    
    // Navigation
    Place my_place <- nil;
    list<Guest> friends <- [];
    point target_point <- nil;
    int time_at_place <- 0;
    
    // Visuals
    rgb color <- #blue;
    float size <- 1.0;

    // ------------------------------------------------------------------
    // Challenge 2: Reinforcement Learning Variables
    // ------------------------------------------------------------------
    // Q-Table: Maps place type ("bar", "cafe", etc.) to an expected reward value
    map<string, float> q_values <- ["bar"::0.0, "concert"::0.0, "cafe"::0.0, "club"::0.0];
    
    // Accumulator for reward during a single visit
    float session_reward <- 0.0; 
    
    // Learning Parameters
    float learning_rate <- 0.2; // Alpha: How fast they adopt new info
    float epsilon <- 0.3;       // Exploration rate: Chance to try a random place
    float discount_factor <- 0.1; // Not strictly needed for 1-step bandit, but kept for structure

    // ------------------------------------------------------------------
    // Movement Logic
    // ------------------------------------------------------------------
    
    reflex check_location {
        Place nearby_place <- one_of(all_places where (each.location distance_to location < 12.0));
        
        if (target_point = nil) {
            // ENTERING A PLACE
            if (nearby_place != nil and my_place = nil) {
                my_place <- nearby_place;
                time_at_place <- 0;
                session_reward <- 0.0; // Reset reward tracker for this visit
                write name + " entered " + my_place.place_type;
            } 
            // LEAVING A PLACE (physically just stepped out)
            else if (nearby_place = nil and my_place != nil) {
                // Logic moved to 'reflex leave' to ensure learning happens *before* pointer is null
            }
        }
    }

    // RL DECISION MAKING: Choose Target based on Q-Values
    reflex choose_target when: target_point = nil and my_place = nil {
        if (!empty(all_places)) {
            
            string chosen_type <- nil;

            // Epsilon-Greedy Strategy:
            // Explore (Random) OR Exploit (Best Q-Value)
            if (flip(epsilon)) {
                // Explore: Pick random
                 chosen_type <- one_of(q_values.keys);
            } else {
                // Exploit: Pick the key with the highest value
                float max_val <- -9999.9;
                loop type over: q_values.keys {
                    if (q_values[type] > max_val) {
                        max_val <- q_values[type];
                        chosen_type <- type;
                    }
                }
            }
            
            // Find a specific venue of that chosen type
            list<Place> candidates <- all_places where (each.place_type = chosen_type);
            if (!empty(candidates)) {
                target_point <- one_of(candidates).location;
            } else {
                // Fallback
                target_point <- one_of(all_places).location;
            }
        }
    }

    reflex move when: target_point != nil {
        do goto target: target_point speed: 2.5;
        if (location distance_to target_point < 5.0) {
            target_point <- nil;
        }
    }

    reflex socialize when: my_place != nil {
        if (flip(0.5)) { do wander speed: 0.8 amplitude: 90.0; }
        time_at_place <- time_at_place + 1;

        // Interaction logic
        if (flip(0.3)) {
            list<Guest> people_here <- my_place.current_guests - self;
            if (length(people_here) > 0) {
                Guest partner <- one_of(people_here);
                if (partner != nil) {
                    do interact_with(partner);
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // RL Logic: Learning Step
    // ------------------------------------------------------------------
    action learn_from_experience {
        if (my_place != nil) {
            string p_type <- my_place.place_type;
            
            // Get current Q value
            float old_q <- q_values[p_type];
            
            // Q-Learning Update Rule (Simplified for Contextual Bandit)
            // NewQ = OldQ + Alpha * (Reward - OldQ)
            // If session_reward is negative, Q value goes down.
            float new_q <- old_q + learning_rate * (session_reward - old_q);
            
            q_values[p_type] <- new_q;
            
            // Decay exploration rate slightly over time (Agents become more set in their ways)
            epsilon <- max(0.05, epsilon * 0.99); 
        }
    }

    reflex leave when: my_place != nil {
        // Leave condition: Time up OR very unhappy OR random chance
        // Added logic: If happiness drops too low, leave earlier (Reactive)
        bool bad_time <- session_reward < -0.2; 
        
        if (time_at_place > 100 or flip(0.05) or bad_time) {
            
            // TRIGGER LEARNING BEFORE LEAVING
            do learn_from_experience;
            
            write name + " leaving " + my_place.place_type + " with reward: " + session_reward + " | New Q: " + q_values[my_place.place_type];

            // Mechanical leaving logic
            target_point <- any_location_in(shape);
            int attempts <- 0;
            loop while: (target_point distance_to my_place.location < 20.0) and attempts < 10 {
                target_point <- any_location_in(shape);
                attempts <- attempts + 1;
            }
            my_place <- nil;
            time_at_place <- 0;
            social_energy <- social_energy * 0.95;
        }
    }

    reflex recover when: my_place = nil {
        social_energy <- min(1.0, social_energy + 0.01);
    }

    // --- Interaction Rules & Reward Calculation ---
    action interact_with(Guest other) {
        float compatibility <- calculate_compatibility(other);
        
        // Calculate the happiness change (Reward delta)
        float happiness_delta <- 0.0;

        if (compatibility > 0.5) {
            happiness_delta <- 0.05;
            total_positive_interactions <- total_positive_interactions + 1;
            if (compatibility > 0.8 and flip(0.1) and !(other in friends)) {
                friends <- friends + other;
                other.friends <- other.friends + self;
                total_friendships_formed <- total_friendships_formed + 1;
            }
        } else {
            happiness_delta <- -0.03;
            total_negative_interactions <- total_negative_interactions + 1;
        }

        // Apply happiness
        happiness <- min(1.0, max(0.0, happiness + happiness_delta));
        other.happiness <- min(1.0, max(0.0, other.happiness + happiness_delta));
        
        // --- RL REWARD ACCUMULATION ---
        // Add the result of this interaction to the session reward
        session_reward <- session_reward + happiness_delta;
        // The other person also learns
        if (other.my_place != nil) {
             other.session_reward <- other.session_reward + happiness_delta;
        }
    }

    float calculate_compatibility(Guest other) {
        return 0.5;
    }

    // FIPA Comm
    reflex send_message when: flip(0.01) and length(friends) > 0 {
        Guest friend <- one_of(friends);
        if (friend != nil) {
            do start_conversation to: [friend] protocol: 'fipa-request' performative: 'inform' contents: ['Hi', happiness];
        }
    }
    reflex receive_message when: !empty(informs) {
        happiness <- min(1.0, happiness + 0.02);
        // Getting a message is also a small reward, wherever you are
        session_reward <- session_reward + 0.02;
        informs <- [];
    }

    aspect default {
        draw circle(size) color: color border: #black;
        if (happiness > 0.8) { draw circle(size/2) color: #gold at: location + {0, 1.5}; }
        else if (happiness < 0.3) { draw circle(size/2) color: #black at: location + {0, 1.5}; }
    }
}

// --- Subclasses ---

species PartyPerson parent: Guest {
    init { extroversion <- rnd(0.7, 1.0); color <- #yellow; size <- 1.5; } 
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        if (my_place != nil and my_place.noise_level > 0.6) { comp <- comp + 0.2; }
        if (other.extroversion > 0.6) { comp <- comp + 0.3; } 
        else if (other.extroversion < 0.3) { comp <- comp - 0.2; }
        return comp;
    }
}

species IntrovertPerson parent: Guest {
    init { extroversion <- rnd(0.0, 0.4); color <- #blue; size <- 0.8; }
    
    // Introverts naturally hate noise. This is built into their compatibility/happiness logic.
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        if (my_place != nil and my_place.noise_level < 0.5) { comp <- comp + 0.3; }
        else { 
            // Being in a loud place actively lowers compatibility/happiness
            comp <- comp - 0.2; 
        }
        if (other.extroversion < 0.5) { comp <- comp + 0.3; }
        else { comp <- comp - 0.1; }
        return comp;
    }
    
    // Specific override: Introverts lose happiness just by existing in loud places
    reflex noise_stress when: my_place != nil {
        if (my_place.noise_level > 0.8 and flip(0.1)) {
            session_reward <- session_reward - 0.05; // Direct penalty
        }
    }
}

species MusicLover parent: Guest {
    init { music_preference <- rnd(0.8, 1.0); color <- #purple; size <- 1.2; }
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        if (my_place != nil and my_place.place_type = "concert") { comp <- 0.9; }
        if (other.music_preference > 0.7) { comp <- comp + 0.4; }
        return comp;
    }
}

species HealthEnthusiast parent: Guest {
    init { health_consciousness <- rnd(0.8, 1.0); color <- #green; size <- 1.0; }
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        if (my_place != nil and my_place.place_type = "bar") { comp <- 0.1; }
        if (my_place != nil and my_place.place_type = "cafe") { comp <- 0.7; }
        if (other.health_consciousness > 0.6) { comp <- comp + 0.3; }
        return comp;
    }
}

species SocialButterfly parent: Guest {
    init { extroversion <- 1.0; generosity <- rnd(0.6, 1.0); color <- #orange; size <- 1.3; }
    float calculate_compatibility(Guest other) {
        float comp <- 0.6;
        if (other.generosity > 0.5) { comp <- comp + 0.2; }
        if (other.extroversion > 0.5) { comp <- comp + 0.1; }
        return comp;
    }
}

experiment SocialSimulationRL type: gui {
    parameter "Number of guests" var: nb_guests min: 20 max: 100;
    
    output {
        display "Social World" type: 3d {
            species Bar; species Concert; species Cafe; species Club;
            species PartyPerson; species IntrovertPerson; species MusicLover;
            species HealthEnthusiast; species SocialButterfly;
        }

        display "Learning Dashboard" {
            // Chart 1: Global Happiness (Standard Requirement)
            chart "Global Happiness" type: series size: {1, 0.33} position: {0, 0} {
                data "Avg Happiness" value: global_happiness color: #blue;
            }
            
            // Chart 2: PROOF OF LEARNING (Challenge 2 Requirement)
            // expect Party People to have high Q for Clubs, and Introverts to have low Q (dropping below 0).
            chart "Learning: Avg Preference (Q-Value) for CLUBS" type: series size: {1, 0.33} position: {0, 0.33} {
                data "Party People Pref" value: avg_party_q_club color: #orange thickness: 2;
                data "Introverts Pref" value: avg_introvert_q_club color: #blue thickness: 2;
            }

            // Chart 3: Interactions
            chart "Interaction Metrics" type: series size: {1, 0.33} position: {0, 0.66} {
                data "Net Interactions" value: total_positive_interactions - total_negative_interactions color: #green;
            }
        }
    }
}