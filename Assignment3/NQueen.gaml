/**
* Name: Assignment3_Task1: NQueens
* Based on the internal empty template. 
* Author: esther(jingmeng)
* Description: Task1: N-Queens problems
*/

model NQueens 

global skills: [fipa] { 
    int N <- 20 min: 4 max: 20; //Number of queens 
    bool solution_found <- false; //flag of solution 
    
    // grid: N*N
    geometry shape <- rectangle(N * 10, N * 10); //According to the N
    
    init { 
        //agnet:queen(N) 
        create queen number: N { 
            //Location 
            // Each queen is assigned a fixed column, and they only need to decide on the row number where they will stand.
            my_col <- int(self); //index
            //The initial position is set outside the screen (-10), not yet entered the game.
            location <- {my_col * (10.0) + 5.0, -10}; 
        } 
        
        //Linked List
        //Each Queen knows its Predecessor and Successor
        loop i from: 0 to: N - 1 { 
            queen q <- queen[i]; 
            //predecessor & successor 
            if (i > 0) { 
                q.predecessor <- queen[i-1]; 
            } 
            if (i < N - 1) { 
                q.successor <- queen[i+1]; 
            } 
        } 
        
        //Send the "start" message to the 0th queen to begin the calculation.
        do start_conversation to: [queen[0]] protocol: 'no-protocol' 
            performative: 'inform' contents: ["start"]; 
    } 
} 

//Grid Network(N*N) 
grid board_cell width: N height: N neighbors: 0 { 
    init { 
        color <- ((grid_x + grid_y) mod 2 = 0) ? #white : #gray; 
    } 
} 

species queen skills: [fipa] { 
    int my_col; //column：unfixed 
    int my_row <- -1; //row(-1: unplaced) 
    queen predecessor; 
    queen successor; 
    list<int> untried_rows; 
    list<int> history_cache; 
    
    aspect default { 
        if (my_row != -1) { 
            //red cycle of queen
            draw circle(4.0) color: #red border: #black; 
            draw string(my_col) color: #white size: 10 at: location - {1.5,0}; 
        } 
    } 
    
    // --- core logic --- 
    
    //Receive the previous previous_positions
    //reset all possible rows (from 0 to N-1), shuffle the order
    //call the find_valid_position function to start the attempt to place.
    reflex receive_message when: !empty(mailbox) { 
        // Obtain and manually remove the message from mailbox 
        message msg <- first(mailbox); 
        remove msg from: mailbox; 
        
        list<unknown> content_list <- list<unknown>(msg.contents); 
        string content_header <- string(content_list[0]); 
        
        //Extract the historical location list (previous_positions) sent by the predecessor. 
        if (content_header = "start" or content_header = "find") { 
            list<int> previous_positions <- []; 
            if (content_header = "find") { 
                previous_positions <- list<int>(content_list[1]); 
            } 
            
            history_cache <- previous_positions; 
            // Reset all possible rows of this column 
            untried_rows <- list(0 to N-1); 
            //shuffle mix order 
            untried_rows <- shuffle(untried_rows); 
            //Start attempting to place 
            do find_valid_position(); 
        } else if (content_header = "backtrack") { 
            // Received the rollback request, continue to attempt the remaining rows 
            do find_valid_position(); 
        } 
    } 
    
    action find_valid_position { 
        if (!empty(untried_rows)) { 
            int row_to_try <- untried_rows[0]; 
            remove row_to_try from: untried_rows; 
            
            // safe: update location; add to history 
            if (is_safe(row_to_try, history_cache)) { 
            	//update location
                my_row <- row_to_try; 
                location <- {my_col * 10.0 + 5.0, my_row * 10.0 + 5.0}; 
                
                list<int> new_history <- history_cache + [my_row]; 
                
                //Last Queen(successor = nil) 
                if (successor = nil) { 
                    write "SOLUTION FOUND: " + new_history; 
                    solution_found <- true; 
                    //Stop 
                    // find all the solutions：“Provide multiple arrangements for your queens.”
                     do start_conversation to: [self] protocol: 'no-protocol' 
                         performative: 'inform' contents: ["backtrack"]; 
                } else { 
                    // Not the last Queen: send to next Queen(successor) 
                    do start_conversation to: [successor] protocol: 'no-protocol' 
                        performative: 'inform' contents: ["find", new_history]; 
                } 
            } else { 
                // Conflict handling: selected row is not safe -> untried_rows's next row 
                do find_valid_position(); 
            } 
        } else { 
            // finish, feedback 
            my_row <- -1; 
            location <- {my_col * 10.0 + 5.0, -10}; 
            
            if (predecessor != nil) { 
                // nofity previous one 
                do start_conversation to: [predecessor] protocol: 'no-protocol' 
                    performative: 'inform' contents: ["backtrack"]; 
            } else { 
                write "SEARCH ENDED (No more solutions)"; 
            } 
        } 
    } 
    
    //Collision detection
    bool is_safe (int try_row, list<int> history) { 
        if (empty(history)) { 
            return true; 
        } 
        
        loop i from: 0 to: length(history) - 1 { 
            int other_row <- history[i]; 
            int other_col <- i; 
            
            //Handle row and diagonal conflict 
            if (try_row = other_row) { 
                return false; 
            } 
            if (abs(my_col - other_col) = abs(try_row - other_row)) { 
                return false; 
            } 
        } 
        return true; 
    } 
} 

experiment NQueens_Task type: gui { 
    parameter "Number of Queens (N)" var: N min: 4 max: 20; 
    
    output synchronized: true {
        display Board type: java2D {
            grid board_cell border: #black;
            species queen aspect: default;
        }
    } 
}