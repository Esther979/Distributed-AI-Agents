/**
* Name: Final Project - BDI Version
* Description: Full implementation of Basic part using BDI Architecture
*/

model finalCha1

global {
    // Requirement 5: At least 50 guests (60 total here)
    int nb_guests <- 60; 
    
    // Requirement 4: At least 2 different types of places
    int nb_bars <- 2;
    int nb_concerts <- 1;
    int nb_cafes <- 2;
    int nb_clubs <- 1;

    list<Place> all_places <- [];

    // Requirement 8: Global interesting values
    float global_happiness <- 0.5;
    float global_social_energy <- 0.5;
    int total_positive_interactions <- 0;
    int total_negative_interactions <- 0;
    int total_friendships_formed <- 0;

    // History for charts
    list<float> happiness_history <- [];
    list<int> interaction_history <- [];

    geometry shape <- square(100);

    init {
        write "Simulation initializing (BDI Mode)...";
        create Bar number: nb_bars;
        create Concert number: nb_concerts;
        create Cafe number: nb_cafes;
        create Club number: nb_clubs;

        all_places <- Bar + Concert + Cafe + Club;

        // Requirement 1: 5 different types of guests
        // Modified to meet the 50+ guests requirement
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

// --- Guest (BDI) ---
species Guest skills: [fipa, moving] control: simple_bdi {
    // Traits
    float extroversion <- rnd(1.0);
    float generosity <- rnd(1.0);
    float music_preference <- rnd(1.0);
    float health_consciousness <- rnd(1.0);

    float happiness <- 0.5;
    float social_energy <- 0.5;

    // --- State variables ---
    string current_activity_name <- "Wandering"; 

    Place my_place <- nil;
    list<Guest> friends <- [];
    point target_point <- nil;
    
    int time_at_place <- 0;
    rgb color <- #blue;
    float size <- 1.0;

    // --- BDI Predicates ---
    predicate desire_wander <- new_predicate("wander");
    predicate desire_move <- new_predicate("move_to_target");
    predicate desire_socialize <- new_predicate("socialize");

    init {
        do add_desire(desire_wander);
    }

    // --- PERCEPTION ---
    reflex check_location {
        Place nearby_place <- one_of(all_places where (each.location distance_to location < 12.0));
        
        if (target_point = nil) {
            if (nearby_place != nil and my_place = nil) {
                my_place <- nearby_place;
                time_at_place <- 0;
                
                do remove_intention(desire_wander, true);
                do remove_intention(desire_move, true);
                do add_desire(desire_socialize);
            } 
            else if (nearby_place = nil and my_place != nil) {
                my_place <- nil;
                time_at_place <- 0;
                
                do remove_intention(desire_socialize, true);
                do add_desire(desire_wander);
            }
        }
    }

    // --- PLANS ---

    plan socialize intention: desire_socialize {
        current_activity_name <- "Socializing"; 

        if (my_place = nil) {
            do remove_intention(desire_socialize, true);
            do add_desire(desire_wander);
            return; 
        }

        if (flip(0.5)) { do wander speed: 0.8 amplitude: 90.0; }
        time_at_place <- time_at_place + 1;

        if (flip(0.3)) {
            list<Guest> people_here <- my_place.current_guests - self;
            if (length(people_here) > 0) {
                Guest partner <- one_of(people_here);
                if (partner != nil) {
                    do interact_with(partner);
                }
            }
        }

        if (time_at_place > 100 or flip(0.05)) {
            target_point <- any_location_in(shape);
            int attempts <- 0;
            loop while: (target_point distance_to my_place.location < 20.0) and attempts < 10 {
                target_point <- any_location_in(shape);
                attempts <- attempts + 1;
            }
            
            my_place <- nil; 
            time_at_place <- 0;
            social_energy <- social_energy * 0.95;
            
            do remove_intention(desire_socialize, true);
            do add_desire(desire_move);
        }
    }

    plan move_to_target intention: desire_move {
        current_activity_name <- "Moving"; 

        if (target_point = nil) {
            do remove_intention(desire_move, true);
            do add_desire(desire_wander);
            return;
        }

        do goto target: target_point speed: 2.5;

        if (location distance_to target_point < 5.0) {
            target_point <- nil;
            do remove_intention(desire_move, true);
            do add_desire(desire_wander);
        }
    }

    plan wander_around intention: desire_wander {
        current_activity_name <- "Wandering"; 

        if (my_place != nil) {
             do remove_intention(desire_wander, true);
             do add_desire(desire_socialize);
             return;
        }

        bool target_found <- false;

        if (flip(0.05)) {  
            if (!empty(all_places)) {
                target_point <- one_of(all_places).location;
                target_found <- true;
            }
        } 
        
        if (!target_found and flip(0.1) and !empty(all_places)) {
            target_point <- one_of(all_places).location;
            target_found <- true;
        }

        if (target_found) {
            do remove_intention(desire_wander, true);
            do add_desire(desire_move);
        } else {
            do wander speed: 1.5;
        }
    }

    reflex recover when: my_place = nil {
        social_energy <- min(1.0, social_energy + 0.01);
    }

    reflex send_message when: flip(0.01) and length(friends) > 0 {
        Guest friend <- one_of(friends);
        if (friend != nil) {
            do start_conversation to: [friend] protocol: 'fipa-request' performative: 'inform' contents: ['Hi', happiness];
        }
    }

    reflex receive_message when: !empty(informs) {
        happiness <- min(1.0, happiness + 0.02);
        informs <- [];
    }

    action interact_with(Guest other) {
        float compatibility <- calculate_compatibility(other);

        if (compatibility > 0.5) {
            happiness <- min(1.0, happiness + 0.05);
            other.happiness <- min(1.0, other.happiness + 0.05);
            total_positive_interactions <- total_positive_interactions + 1;

            if (compatibility > 0.8 and flip(0.1) and !(other in friends)) {
                friends <- friends + other;
                other.friends <- other.friends + self;
                total_friendships_formed <- total_friendships_formed + 1;
                
                // --- print friendship ---
                write ">>> NEW FRIENDSHIP: " + name + " became friends with " + other.name;
            }
        } else {
            happiness <- max(0.0, happiness - 0.03);
            other.happiness <- max(0.0, other.happiness - 0.03);
            total_negative_interactions <- total_negative_interactions + 1;
        }
    }

    float calculate_compatibility(Guest other) {
        return 0.5; 
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
    
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        if (my_place != nil and my_place.noise_level < 0.5) { comp <- comp + 0.3; }
        else { comp <- comp - 0.2; }
        if (other.extroversion < 0.5) { comp <- comp + 0.3; }
        else { comp <- comp - 0.1; }
        return comp;
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

experiment SocialSimulation type: gui {
    parameter "Number of guests" var: nb_guests min: 20 max: 100;

    output {
        display "Social World" type: 3d {
            species Bar; species Concert; species Cafe; species Club;
            species PartyPerson; species IntrovertPerson; species MusicLover;
            species HealthEnthusiast; species SocialButterfly;
        }

        display "Statistics Dashboard" {
            chart "Global Happiness Index" type: series size: {1, 0.5} position: {0, 0} {
                data "Avg Happiness" value: global_happiness color: #blue style: line thickness: 2;
                data "Social Energy" value: global_social_energy color: #orange style: line;
            }
            chart "Interaction Metrics" type: series size: {1, 0.5} position: {0, 0.5} {
                data "Total Friendships" value: total_friendships_formed color: #purple thickness: 2;
                data "Net Interactions (Pos - Neg)" value: total_positive_interactions - total_negative_interactions color: #green;
            }
        }
    }
}