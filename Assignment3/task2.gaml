/**
* Name: Assignment3_Task2: Festival Stages
* Description: Task 2
* Dimensions: LightShow, Speaker, MusicStyle
*/

model FestivalStages

global {
    int number_of_stages <- 4;
    int number_of_guests <- 20;
    
    init {
        create stage number: number_of_stages {
            location <- {rnd(10, 90), rnd(10, 90)};
            
            val_light_show <- rnd(1.0);
            val_speaker <- rnd(1.0);
            val_music_style <- rnd(1.0);
            
            // Stage color: R=Light, G=Speaker, B=Music
            color <- rgb(val_light_show*255, val_speaker*255, val_music_style*255);
        }

        create guest number: number_of_guests {
            location <- {50, 50}; 
            
            //preference of guests
            pref_light_show <- rnd(1.0);
            pref_speaker <- rnd(1.0);
            pref_music_style <- rnd(1.0);
        }

        // --- 3. 控制台打印数据 ---
//        write "==========================================================";
//        write "                    STAGE CONFIGURATION                   ";
//        write "==========================================================";
//        ask stage {
//            write "Stage " + int(self) + " Values: " + 
//                  " LightShow=" + with_precision(val_light_show, 2) + 
//                  " | Speaker=" + with_precision(val_speaker, 2) + 
//                  " | MusicStyle=" + with_precision(val_music_style, 2);
//        }
//        
//        write "==========================================================";
//        write "               GUEST PREFERENCES (Weights)                ";
//        write "==========================================================";
//        ask guest {
//            write "Guest " + int(self) + " Weights: " + 
//                  " Light=" + with_precision(pref_light_show, 2) + 
//                  " | Speaker=" + with_precision(pref_speaker, 2) + 
//                  " | Music=" + with_precision(pref_music_style, 2);
//        }
//        write "==========================================================\n";
    }
}

species stage skills: [fipa] {
    
    float val_light_show;
    float val_speaker;
    float val_music_style;
    rgb color;

    aspect default {
        draw square(6) color: color border: #black;
        draw "Stage " + int(self) color: #black size: 4 at: location + {0, -5};
        
        // show the value on map
        draw "Light: " + with_precision(val_light_show, 2) color: #black size: 2.5 at: location + {4, -2};
        draw "Spkr:  " + with_precision(val_speaker, 2) color: #black size: 2.5 at: location + {4, 0};
        draw "Music: " + with_precision(val_music_style, 2) color: #black size: 2.5 at: location + {4, 2};
    }

    reflex reply_to_guest when: !empty(mailbox) {
        message request <- first(mailbox);
        remove request from: mailbox;
        
        list<unknown> request_content <- list<unknown>(request.contents);
        string content <- string(request_content[0]);
        
        if (content = "ask_attributes") {
            
            do start_conversation to: [request.sender] 
                                  protocol: 'fipa-request' 
                                  performative: 'inform' 
                                  contents: ["stage_info", val_light_show, val_speaker, val_music_style];
        }
    }
}

species guest skills: [fipa, moving] {

    float pref_light_show;
    float pref_speaker;
    float pref_music_style;
    
    bool decided <- false;
    stage target_stage <- nil;
    
    aspect default {
        draw circle(1.5) color: #red border: #black;
        draw string(int(self)) color: #black size: 3 at: location + {2, 2};
    }

    reflex ask_stages when: !decided and empty(mailbox) and target_stage = nil {
        list<stage> all_stages <- list(stage);
        do start_conversation to: all_stages 
                              protocol: 'fipa-request' 
                              performative: 'request' 
                              contents: ["ask_attributes"];
    }

    reflex receive_and_decide when: !decided and !empty(mailbox) and (length(mailbox) = number_of_stages) {
        
        float max_utility <- -1.0;
        stage best_stage <- nil;
        
        loop msg over: mailbox {
            list<unknown> content_list <- list<unknown>(msg.contents);
            string header <- string(content_list[0]);
            
            if (header = "stage_info") {
                stage sender_stage <- stage(msg.sender);
                
                // receive attribute value
                float s_light <- float(content_list[1]);
                float s_speaker <- float(content_list[2]);
                float s_music <- float(content_list[3]);
 
                // Utility = (w_light * v_light) + (w_speaker * v_speaker) + (w_music * v_music)
                float utility <- (pref_light_show * s_light) + 
                                 (pref_speaker * s_speaker) + 
                                 (pref_music_style * s_music);
                
                if (utility > max_utility) {
                    max_utility <- utility;
                    best_stage <- sender_stage;
                }
            }
        }
        
        if (best_stage != nil) {
            target_stage <- best_stage;
            decided <- true;
            write ">>> RESULT: Guest " + int(self) + " selected Stage " + int(best_stage) + " (Utility: " + with_precision(max_utility, 3) + ")";
        }
    }

    reflex move_to_stage when: decided and target_stage != nil {
        do goto target: target_stage speed: 2.0;
    }
}

experiment Festival_Task type: gui {
    output {
        display Map type: java2D {
            species stage aspect: default;
            species guest aspect: default;
        }
    }
}
