/**
* Name: Final Project - Basic Social Interaction
* Based on the internal empty template. 
* Author: esther(jingmeng)
* Description: 
*/

model SocialInteraction

global {
    int nb_guests <- 60;
    int nb_bars <- 2;
    int nb_concerts <- 1;
    int nb_cafes <- 2;
    int nb_clubs <- 1;

    list<Place> all_places <- [];

    float global_happiness <- 0.5;
    float global_social_energy <- 0.5;
    int total_positive_interactions <- 0;
    int total_negative_interactions <- 0;
    int total_friendships_formed <- 0;

    // history
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

// --- Guest ---
species Guest skills: [fipa, moving] {
    float extroversion <- rnd(1.0);
    float generosity <- rnd(1.0);
    float tolerance <- rnd(1.0);
    float music_preference <- rnd(1.0);
    float health_consciousness <- rnd(1.0);

    float happiness <- 0.5;
    float social_energy <- 0.5;

    Place my_place <- nil;
    list<Guest> friends <- [];
    point target_point <- nil;
    
    // timer for stay
    int time_at_place <- 0;

    rgb color <- #blue;
    float size <- 1.0;

    // Only check the position upon truly reaching the destination to avoid being judged as "in the store" halfway.
    reflex check_location {
        Place nearby_place <- one_of(all_places where (each.location distance_to location < 12.0));
        
        // Update my_place only when there is no moving target
        if (target_point = nil) {
            if (nearby_place != nil and my_place = nil) {
                // just enter the place
                my_place <- nearby_place;
                time_at_place <- 0;
                write name + " entered " + my_place.place_type;
            } else if (nearby_place = nil and my_place != nil) {
                // leave the place
                write name + " left " + my_place.place_type;
                my_place <- nil;
                time_at_place <- 0;
            }
        }
    }

    // Increase the probability of finding the target and make the movement more frequent.
    reflex choose_target when: target_point = nil and my_place = nil {
        if (flip(0.05)) {  
            if (!empty(all_places)) {
                target_point <- one_of(all_places).location;
                write name + " heading to a place";
            }
        } else {
            do wander speed: 1.5;
        }
    }

    // move to target
    reflex move when: target_point != nil {
        do goto target: target_point speed: 2.5;  //move speed

        if (location distance_to target_point < 5.0) {
            target_point <- nil;
            write name + " arrived at destination";
        }
    }

    // still move around when socializing.
    reflex socialize when: my_place != nil {
        // wander in the place
        if (flip(0.5)) {
            do wander speed: 0.8 amplitude: 90.0;
        }
        
        time_at_place <- time_at_place + 1;

        // interaction
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

    // Increase the probability of leaving, or automatically leave based on the duration of stay.
    reflex leave when: my_place != nil {
        // Plan1: Stay for too long and then automatically leave.
        if (time_at_place > 100 or flip(0.05)) {
            // choose a leaving place
            target_point <- any_location_in(shape);
            
            // ensure move away from the place
            int attempts <- 0;
            loop while: (target_point distance_to my_place.location < 20.0) and attempts < 10 {
                target_point <- any_location_in(shape);
                attempts <- attempts + 1;
            }
            
            write name + " is leaving " + my_place.place_type;
            my_place <- nil;  // clear
            time_at_place <- 0;
            social_energy <- social_energy * 0.95;
        }
    }

    // If there is no goal for a long time and you are not at the location, actively seek out a goal.
    reflex find_something_to_do when: my_place = nil and target_point = nil {
        if (flip(0.1)) {
            if (!empty(all_places)) {
                target_point <- one_of(all_places).location;
                write name + " is looking for something to do";
            }
        }
    }

    reflex recover when: my_place = nil {
        social_energy <- min(1.0, social_energy + 0.01);
    }

    // Ineraction logic
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

    float calculate_compatibility(Guest other) {
        float base <- 0.5;
        if (species(self) = species(other)) { base <- 0.7; }
        return base;
    }

    // FIPA message
    reflex send_message when: flip(0.01) and length(friends) > 0 {
        Guest friend <- one_of(friends);
        if (friend != nil) {
            do start_conversation to: [friend] protocol: 'fipa-request' performative: 'inform' contents: ['Hi', happiness];
        }
    }
    reflex receive_message when: !empty(informs) {
        happiness <- min(1.0, happiness + 0.02);
    }

    aspect default {
        draw circle(size) color: color border: #black;
        if (happiness > 0.8) { draw circle(size/2) color: #gold at: location + {0, 1.5}; }
        else if (happiness < 0.3) { draw circle(size/2) color: #black at: location + {0, 1.5}; }
        /*if (target_point != nil) {
            draw line([location, target_point]) color: #gray;
        } */
    }
}

species PartyPerson parent: Guest {
    init { extroversion <- 0.9; color <- #yellow; size <- 1.5; }
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        if (my_place != nil and my_place.noise_level > 0.6) { comp <- comp + 0.2; }
        if (other is PartyPerson) { comp <- 0.9; }
        else if (other is IntrovertPerson) { comp <- 0.2; }
        return comp;
    }
}
species IntrovertPerson parent: Guest {
    init { extroversion <- 0.2; color <- #blue; size <- 0.8; }
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        if (my_place != nil and my_place.noise_level < 0.5) { comp <- comp + 0.3; }
        else { comp <- comp - 0.2; }
        if (other is IntrovertPerson) { comp <- 0.8; }
        else if (other is PartyPerson) { comp <- 0.2; }
        return comp;
    }
}
species MusicLover parent: Guest {
    init { music_preference <- 0.9; color <- #purple; size <- 1.2; }
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        if (my_place != nil and my_place.place_type = "concert") { comp <- 0.9; }
        if (other is MusicLover) { comp <- 0.8; }
        return comp;
    }
}
species HealthEnthusiast parent: Guest {
    init { health_consciousness <- 0.9; color <- #green; size <- 1.0; }
    float calculate_compatibility(Guest other) {
        float comp <- 0.5;
        if (my_place != nil and my_place.place_type = "bar") { comp <- 0.1; }
        if (my_place != nil and my_place.place_type = "cafe") { comp <- 0.7; }
        if (other is HealthEnthusiast) { comp <- 0.9; }
        return comp;
    }
}
species SocialButterfly parent: Guest {
    init { extroversion <- 1.0; color <- #orange; size <- 1.3; }
    float calculate_compatibility(Guest other) { return 0.8; }
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
            chart "Average Happiness" type: series size: {1, 0.5} position: {0, 0} {
                data "Happiness" value: global_happiness color: #blue style: line thickness: 2;
                //data "Ref" value: 0.5 color: #red;
            }
            chart "Interactions" type: series size: {1, 0.5} position: {0, 0.5} {
                data "Friendships" value: total_friendships_formed color: #purple thickness: 2;
                data "Net Interactions" value: total_positive_interactions - total_negative_interactions color: #green;
            }
        }
    }
}