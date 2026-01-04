/**
* Name: Final Project - Basic Social Interaction
* Author: esther(jingmeng)
* Description: Full implementation of Basic part
*/

model SocialInteraction

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
        write "Simulation initializing...";
        create Bar number: nb_bars;
        create Concert number: nb_concerts;
        create Cafe number: nb_cafes;
        create Club number: nb_clubs;

        all_places <- Bar + Concert + Cafe + Club;

        // Requirement 1: 5 different types of guests
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
    float noise_level; // Affects compatibility rules
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

// --- Guest ---
species Guest skills: [fipa, moving] {
    // Requirement 3: At least 3 personal traits that affect rules
    float extroversion <- rnd(1.0);
    float generosity <- rnd(1.0);
    float music_preference <- rnd(1.0);
    float health_consciousness <- rnd(1.0);

    float happiness <- 0.5;
    float social_energy <- 0.5;

    Place my_place <- nil;
    list<Guest> friends <- [];
    point target_point <- nil;
    
    int time_at_place <- 0;
    rgb color <- #blue;
    float size <- 1.0;

    // Movement Logic: Enter/Leave places
    reflex check_location {
        Place nearby_place <- one_of(all_places where (each.location distance_to location < 12.0));
        
        if (target_point = nil) {
            if (nearby_place != nil and my_place = nil) {
                my_place <- nearby_place;
                time_at_place <- 0;
                write name + " entered " + my_place.place_type;
            } else if (nearby_place = nil and my_place != nil) {
                write name + " left " + my_place.place_type;
                my_place <- nil;
                time_at_place <- 0;
            }
        }
    }

    reflex choose_target when: target_point = nil and my_place = nil {
        if (flip(0.05)) {  
            if (!empty(all_places)) {
                target_point <- one_of(all_places).location;
            }
        } else {
            do wander speed: 1.5;
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

    reflex leave when: my_place != nil {
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
        }
    }

    reflex find_something_to_do when: my_place = nil and target_point = nil {
        if (flip(0.1) and !empty(all_places)) {
            target_point <- one_of(all_places).location;
        }
    }

    reflex recover when: my_place = nil {
        social_energy <- min(1.0, social_energy + 0.01);
    }

    // --- Requirement 2 & 3: Interaction Rules affected by Traits ---
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
                write "NEW FRIENDSHIP: " + name + " & " + other.name;
            }
        } else {
            happiness <- max(0.0, happiness - 0.03);
            other.happiness <- max(0.0, other.happiness - 0.03);
            total_negative_interactions <- total_negative_interactions + 1;
        }
    }

    // Default compatibility (overridden by subclasses)
    float calculate_compatibility(Guest other) {
        return 0.5; 
    }

    // Requirement 7: Agent Communication with FIPA
    reflex send_message when: flip(0.01) and length(friends) > 0 {
        Guest friend <- one_of(friends);
        if (friend != nil) {
            do start_conversation to: [friend] protocol: 'fipa-request' performative: 'inform' contents: ['Hi', happiness];
        }
    }
    reflex receive_message when: !empty(informs) {
        happiness <- min(1.0, happiness + 0.02);
        // Clear messages to prevent memory buildup
        informs <- [];
    }

    aspect default {
        draw circle(size) color: color border: #black;
        if (happiness > 0.8) { draw circle(size/2) color: #gold at: location + {0, 1.5}; }
        else if (happiness < 0.3) { draw circle(size/2) color: #black at: location + {0, 1.5}; }
    }
}

// --- Subclasses with Specific Traits Logic ---

species PartyPerson parent: Guest {
    init { extroversion <- rnd(0.7, 1.0); color <- #yellow; size <- 1.5; } // High Extroversion
    
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        // Rule: Likes loud places
        if (my_place != nil and my_place.noise_level > 0.6) { comp <- comp + 0.2; }
        
        // Rule: Likes other high-extroversion people (Trait based)
        if (other.extroversion > 0.6) { comp <- comp + 0.3; } 
        else if (other.extroversion < 0.3) { comp <- comp - 0.2; }
        
        return comp;
    }
}

species IntrovertPerson parent: Guest {
    init { extroversion <- rnd(0.0, 0.4); color <- #blue; size <- 0.8; } // Low Extroversion
    
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        // Rule: Likes quiet places
        if (my_place != nil and my_place.noise_level < 0.5) { comp <- comp + 0.3; }
        else { comp <- comp - 0.2; }
        
        // Rule: Likes people who are not too loud/extroverted (Trait based)
        if (other.extroversion < 0.5) { comp <- comp + 0.3; }
        else { comp <- comp - 0.1; }
        
        return comp;
    }
}

species MusicLover parent: Guest {
    init { music_preference <- rnd(0.8, 1.0); color <- #purple; size <- 1.2; } // High Music Pref
    
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        // Rule: Loves Concerts
        if (my_place != nil and my_place.place_type = "concert") { comp <- 0.9; }
        
        // Rule: Likes others with high music preference (Trait based)
        if (other.music_preference > 0.7) { comp <- comp + 0.4; }
        
        return comp;
    }
}

species HealthEnthusiast parent: Guest {
    init { health_consciousness <- rnd(0.8, 1.0); color <- #green; size <- 1.0; } // High Health
    
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        // Rule: Hates Bars, Loves Cafes
        if (my_place != nil and my_place.place_type = "bar") { comp <- 0.1; }
        if (my_place != nil and my_place.place_type = "cafe") { comp <- 0.7; }
        
        // Rule: Likes others with high health consciousness (Trait based)
        if (other.health_consciousness > 0.6) { comp <- comp + 0.3; }
        
        return comp;
    }
}

species SocialButterfly parent: Guest {
    init { extroversion <- 1.0; generosity <- rnd(0.6, 1.0); color <- #orange; size <- 1.3; }
    
    float calculate_compatibility(Guest other) {
        float comp <- 0.6; // Base is higher
        
        // Rule: Gets along with almost everyone, especially generous people (Trait based)
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

        // Requirement 9: Useful and informative graph
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