/**
* Name: assignment1_bonus2
* Based on the internal empty template. 
* Author: xiao
* Description: challenge 2
*/


model challenge2

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
    
    // Security agent speed (faster than guests)
    float speed_security <- speed_guests * 1.5;
    // Maximum distance for a guest to report a bad guest
    float report_distance <- 10.0; 


	init {
		create infoCenter number: nb_infocenter
		{
			location <- location_infocenter;
		}

		create foodStore number: nb_foodstores;

		create drinkStore number: nb_drinkstores;
		
		// Create Security agent
		create Security number: 1; 
		
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
	
    // Is this guest a bad actor? (20% chance)
    bool isBad <- flip(0.15); 
    // Has this bad guest been reported?
    bool isReported <- false; 

	// Used to store the long-distance target for wandering
	point randomDestination <- nil;
	
    // Color is #darkred for bad guests, #green for others
	rgb color <- #green;
	
	agent target <- nil;
	
	action setName(int num) {
		guestName <- "Guest " + num; 
	}
	
	aspect default{
        if(isBad) {
            color <- #darkred; // Bad guests are dark red
        } else if (target = nil) {
            color <- #green; // Normal guests are green when wandering
        }
		draw circle(2) at: location color: color;
	}
    
    // Reflex for normal guests to find and report bad guests nearby
    reflex reportBadGuest when: !isBad and target = nil {
        // Find any bad guest within the report_distance who hasn't been reported yet
        list<guest> nearbyBadGuests <- guest at_distance report_distance where (each.isBad and not each.isReported);

        if (length(nearbyBadGuests) > 0) {
            guest targetBadGuest <- one_of(nearbyBadGuests);

            // Set the Info Center as the temporary target for reporting
            target <- one_of(infoCenter);
            color <- #purple; // Change color while on reporting mission
            write guestName + ' spotted ' + targetBadGuest.guestName + ' (Bad) and is heading to InfoCenter to report.';
        }
    }
    
    /* Decrements hunger/thirst level randomly each time. 
     * If below 50, asks info center for the nearest store, 
     * prioritizing the lower value (to handle cases where both are below 50). */
    reflex determineTarget when: target = nil{
    	
    	hunger <- hunger-rnd(hungerlevel);
    	thirst <- thirst-rnd(thirstlevel);
    	
    	if(hunger < 50 or thirst < 50){
    		string stateMessage <- guestName;
            
    		// Clear the random wandering target before setting a new target
            randomDestination <- nil; 
            
    		if(hunger <= thirst)
    		{
    			stateMessage <- guestName + ' is hungry, ';
    			
    			ask one_of(infoCenter)
    			{

    				myself.target <- one_of(foodStore closest_to myself);
    				myself.color <- #red;
    			}
    			
    			if (target != nil) {
					stateMessage <- stateMessage + ' heading to the nearest Food Store: ' + target.name;
					write stateMessage;
				}
    		}
    		else
    		{
    			stateMessage <- guestName + ' is thirsty, ';
    			
    			ask one_of(infoCenter)
    			{
    				myself.target <- one_of(drinkStore closest_to myself);
    				myself.color <- #blue;
    			}
    			
    			if (target != nil) {
					stateMessage <- stateMessage + ' heading to the nearest Drink Store: ' + target.name;
					write stateMessage;
				}
    		}
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
    	// color <- #green; // Color update is now in aspect default
    }
    
    //move towards target store or infoCenter (for reporting)
    reflex moveToTarget when: target != nil
    {
    	do goto target: target.location speed: speed_guests;
    }
    
    //Arrived at Info Center to report
    reflex arrivedInfoCenter when: target != nil and target is infoCenter and location distance_to(target.location) < size_infocenter
    {
        ask target
        {
            // Info Center looks for un-reported bad guests nearby (the one the guest is reporting about)
            list<guest> badGuestsToReport <- guest where (each.isBad and not each.isReported);
            
            if (length(badGuestsToReport) > 0) {
                guest badGuest <- one_of(badGuestsToReport); // Choose one to report
                badGuest.isReported <- true; // Mark as reported
                
                ask one_of(Security) {
                    if(!(self.targets contains badGuest)) {
                        self.targets <+ badGuest; // Add to security target list
                        write '🚨 InfoCenter received report and sent Security after: ' + badGuest.guestName;
                    }
                }
            }
        }
        
        // Reporting is done, clear target and resume normal activity
        target <- nil;
        randomDestination <- nil;
        //write guestName + ' ' + hunger;
    }


    //arrived, set to default
 reflex arrivedStore when: target != nil and not (target is infoCenter) and location distance_to(target.location) < 2.5
    {
    	ask target as stores
    	{
    		string getFood <- myself.guestName;
    		if(sellsFood = true)
    		{
    			myself.hunger <- 100.0;
    			myself.target <- nil;
				myself.color <- #green;
				getFood <- getFood + ' ate food at ' + name;
    		}
    		else if(sellsDrink = true)
    		{
    			myself.thirst <- 100.0;
    			myself.target <- nil;
				myself.color <- #green;
				getFood <- getFood + ' had drink at ' + name;
    		}
    		write getFood;
    	}
    	target <- nil;
    }
}
    
species stores
{
    bool sellsFood <- false;
    bool sellsDrink <- false;
}
    
species infoCenter{
    	
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

// Security species for catching bad guests
species Security skills:[moving]
{
    list<guest> targets; // List of bad guests to catch
    
    aspect default
	{
		draw triangle(5) at: location color: #black;
	}
    
    reflex patrol when: length(targets) = 0
	{ 
	    do wander; 
	}

    // Reflex to chase the first target in the list
	reflex catchBadGuest when: length(targets) > 0
	{
		// Check if the target is still alive (important)
		if(dead(targets[0]))
		{
			targets >- first(targets); // Remove dead target
		}
		else
		{
			do goto target:(targets[0].location) speed: speed_security;
		}
	}
	
    // Reflex to "exterminate" the bad guest once caught
	reflex badGuestCaught when: length(targets) > 0 and !dead(targets[0]) and location distance_to(targets[0].location) < 0.5
	{
		ask targets[0]
		{
			write guestName + ': exterminated by Security!';
			do die; // Remove the bad guest from the simulation
		}
		targets >- first(targets); // Remove target from security list
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
			species Security; // Add Security to the display
		}
	}
}