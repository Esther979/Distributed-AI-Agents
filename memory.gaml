/**
* Name: memory
* Based on the assignment1 basic
* Author: esther
* Description: Challenge 1: Memory of Agents - Small Brain
*/


model memory

/* Insert your model definition here */

global {
    
    int nb_guests <- 15;
    int nb_foodstores <- 3;
    int nb_drinkstores <- 3;
    int nb_infocenter <- 1;
    point location_infocenter <- {50,50};
    int size_infocenter <- 5;
    float speed_guests <- 3.0;
    float hungerlevel <- 10.0;
    float thirstlevel <- 10.0;
    
    // Global parameter to uniformly control the movement range of Guests
    int world_dimension <- 100;


	init {
		create infoCenter number: nb_infocenter
		{
			location <- location_infocenter;
		}

		create foodStore number: nb_foodstores;

		create drinkStore number: nb_drinkstores;
		create guest number: nb_guests;


	loop counter from: 1 to: nb_guests {
		    guest my_agent <- guest[counter - 1];
		    my_agent <- my_agent.setName(counter);
		    }


	}
}

species guest skills: [moving] {
	
	//initial huger/thirst
	float hunger <- 100.0;
	float thirst <- 100.0;
	string guestName <- "Undefined";
	
	//2.1 Memory and distance
	list<stores> memory <- [];     // stores remembered
	float totalDistance <- 0.0;    // accumulated distance traveled
	float explorationProbability <- 0.3; // 30% chance to discover new place instead of memory
	point last_location <- nil;    // used for distance tracking
	
	
	// Used to store the long-distance target for wandering
	point randomDestination <- nil;
	
	rgb color <- #green;
	
	stores target <- nil;
	
	action setName(int num) {
		guestName <- "Guest " + num; 
	}
	
	aspect default{
		draw circle(2) at: location color: color;
	}
    
    //2.2 Remember distance
    reflex trackDistance {
	    if last_location != nil {
	        totalDistance <- totalDistance + (location distance_to last_location);
	    }
	    last_location <- location;
	}
	
    /* Decrements hunger/thirst level randomly each time. 
     * If below 50, asks info center for the nearest store, 
     * prioritizing the lower value (to handle cases where both are below 50). */
    reflex determineTarget when: target = nil{
    	
    	hunger <- hunger-rnd(hungerlevel);
    	thirst <- thirst-rnd(thirstlevel);
    	
    	if(hunger < 50 or thirst < 50){
    		//2.3 Use memory to find stores
    		bool useMemory <- (rnd(1.0) > explorationProbability);

			// Select from memory if possible
    		if(hunger <= thirst){ // Need food first
    			if(useMemory and any(memory where (each.sellsFood))) {
    				target <- first((memory where (each.sellsFood)) sort_by (each.location distance_to location));
    				color <- #red;
    			} else {
    				ask one_of(infoCenter) {
    					myself.target <- one_of(foodStore closest_to myself);
    					myself.color <- #red;
    				}
    			}
    		}
    		else { // Need drink first
    			if(useMemory and any(memory where (each.sellsDrink))) {
    				target <- first((memory where (each.sellsDrink)) sort_by (each.location distance_to location));
    				color <- #blue;
    			} else {
    				ask one_of(infoCenter) {
    					myself.target <- one_of(drinkStore closest_to myself);
    					myself.color <- #blue;
    				}
    			}
    		}

    		randomDestination <- nil;
    	}
    }
    
	    
    
    // defalut state
    reflex normalState when: target = nil
    {
        /* 1. If there is no random destination, 
         * or if the agent is close to the destination (distance less than 5), 
         select a new destination. */
        if (randomDestination = nil or location distance_to randomDestination < 5) {
			// Generate a random coordinate within the entire map range
			randomDestination <- point(rnd(world_dimension), rnd(world_dimension));
		}
		
		// 2. Move towards this destination
    	do goto target: randomDestination speed: speed_guests;
    	color <- #green; // Keep green while wandering
    }
    
    //move towards target store
    reflex moveToTarget when: target != nil
    {
    	do goto target: target.location speed: speed_guests;
    }
    
    //Add arrived stores into memory
    reflex arrivedStore when: target != nil and location distance_to(target.location) < 2.5 {
    	ask target {
    		if(sellsFood) {
    			myself.hunger <- 100.0;
    		}
    		if(sellsDrink) {
    			myself.thirst <- 100.0;
    		}

    		if(not (self in myself.memory)) {
    			myself.memory <- myself.memory + self;
    		}

    		write myself.guestName + " visited " + name;
    	}
    	target <- nil;
    	color <- #green;
    }
}
    
species stores
{
    bool sellsFood <- false;
    bool sellsDrink <- false;
}
    
species infoCenter parent: stores{
    	
    list<foodStore> foodstores <- (foodStore at_distance 100);
    list<drinkStore> drinkstores <- (drinkStore at_distance 100);
    	
    bool hasLocations <- false;
	
	reflex listStoreLocations when: hasLocations = false
	{
		ask foodStore
		{
			write "Food store at:" + location; 
		}	
		
		ask drinkStore
		{
			write "Drink store at:" + location; 
		}
		
		hasLocations <- true;
	}
	
	aspect default
	{
		draw sphere(3) at: location color: #orange;
	}
	
}


species foodStore parent: stores
{
	bool sellsFood <- true;
		
	aspect default
	{
		draw pyramid(5) at: location color: #brown;
	}
}
	

species drinkStore parent: stores
{
	bool sellsDrink <- true;
		
	aspect default
	{
		draw pyramid(5) at: location color: #lightblue;
	}
}

experiment main type: gui
{
	
	output
	{
		display map type: opengl
		{
			species guest;
			species foodStore;
			species drinkStore;
			species infoCenter;
		}
		//compare distance
		monitor "Average distance traveled" value: mean(guest collect (each.totalDistance));
        monitor "Average memory size" value: mean(guest collect (length(each.memory)));
	}
}
