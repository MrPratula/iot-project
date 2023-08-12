
 
#include "Timer.h"
#include "RadioRoute.h"
#include "printf.h"	


module RadioRouteC @safe() {
    uses {

        /****** INTERFACES *****/
        interface Boot;

        //interfaces for communication
        interface SplitControl as AMControl;
        interface Receive;
        interface AMSend;
        interface Packet;

        //interface for timers
        interface Timer<TMilli> as Timer0;
        interface Timer<TMilli> as Timer1;

        interface Timer<TMilli> as TimerStart;
        interface Timer<TMilli> as Timer3;

        //other interfaces, if needed
        interface Random;
    }
}




implementation {

    message_t packet;

    // Variables to store the message to send
    message_t queued_packet;
    uint16_t queue_addr;
    uint16_t time_delays[8]={61,173,267,371,479,583,689,793}; //Time delay in milli seconds


    bool route_req_sent=FALSE;
    bool route_rep_sent=FALSE;


    bool locked;

    bool actual_send (uint16_t address, message_t* packet);
    bool generate_send (uint16_t address, message_t* packet, uint8_t type);

    
    uint16_t token;
  

  
    typedef struct sent {

        bool lock;
        uint16_t src;
        uint16_t dst;
        uint16_t sender;
        uint16_t next_hop;
        uint16_t token;
        uint16_t id;
        uint16_t rtx;

        uint16_t type;
        uint16_t data;

    } Box;

    Box sent[32];
	
	
	
	typedef struct sto {
	
		bool lock;
		uint16_t sender;
		uint16_t token;
        uint16_t id;
	
	} Sto;

	Sto storage[128];





    bool generate_send (uint16_t address, message_t* packet, uint8_t type){


        if (call Timer0.isRunning()){
            dbg("error", "BAD generate send OUT cuz timer0 is running \n\n");
            return FALSE;
        }else{
            if (type == 0){		//data
            	queued_packet = *packet;
                queue_addr = address;
                call Timer0.startOneShot( time_delays[TOS_NODE_ID-1]  );
                
            }else if (type == 1){ 		//ack
            	queued_packet = *packet;
                queue_addr = address;
                call Timer0.startOneShot( 10 );
                
            } else if(type == 2) { // retransmission
            	queued_packet = *packet;
                queue_addr = address;
                call Timer0.startOneShot( 100 + TOS_NODE_ID*10 ); //
            }
        }
        
        return TRUE;
    }
  




  
    event void Timer0.fired() {
        actual_send (queue_addr, &queued_packet);
    }
  



  
  
    bool actual_send (uint16_t address, message_t* packet){

        

        if (locked) {
            dbg("error", "BAD actual send OUT cuz locked\n\n");
            return FALSE;
        }
        else {
            if (call AMSend.send(address, packet, sizeof(radio_route_msg_t)) == SUCCESS) {
                dbg("radio_send", "Sending packet");
                locked = TRUE;
                dbg_clear("radio_send", " at time %s \n", sim_time_string());
                return TRUE;
            }

        }

    }
  






	event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	    if (&queued_packet == bufPtr) {
	        locked = FALSE;
	        dbg("radio_send", "Packet sent...");
	        dbg_clear("radio_send", " at time %s \n", sim_time_string());
	    }
	    else {
	    	dbg("error", "SUPER BAD in send done");
	    }
	}







    event void Boot.booted() {
        dbg("boot","Application booted.\n");
        dbg("boot","started node %d.\n", TOS_NODE_ID);

        call AMControl.start();

    }
  
  
  
  

    event void AMControl.startDone(error_t err) {

        uint8_t i;

        if (err == SUCCESS) {
            dbg("radio","Radio on on node %d!\n", TOS_NODE_ID);

            token = 0;

            for(i=0; i<=31; i++){
                sent[i].lock = FALSE;
            }
			
			for(i=0; i<=127; i++){
                storage[i].lock = FALSE;
            }
			
	
			// start periodic send for sensor nodes
			if(TOS_NODE_ID <= 5){
			
				call Timer3.startPeriodic(1000*TOS_NODE_ID + time_delays[TOS_NODE_ID-1]);
			
			}

        }
        
        else {
            dbgerror("radio", "Radio failed to start, retrying...\n");
            call AMControl.start();
        }
    }







    event void AMControl.stopDone(error_t err) {
        dbg("boot", "Radio stopped!\n");
    }





  
    





    event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    
	    uint16_t src;
	    uint16_t dst;
	    uint16_t sender;
	    uint16_t tkn;
	    uint16_t id;
	    uint16_t rtx;
	    int16_t data;
	    uint16_t type;
	    uint16_t i;
	    bool dup;

	    radio_route_msg_t* rcm;


	    if (len != sizeof(radio_route_msg_t)) {
	        return bufPtr;
	    }

	    else{
				
				
			switch(TOS_NODE_ID){
			
			case 1:
			case 2:
			case 3:
			case 4:
			case 5:
			
			
				// get received ACK packet
				rcm = (radio_route_msg_t*) payload;
		
				
				tkn = rcm->token;
			    type = rcm->type;
			    dst = rcm->dst;
			    
			    // message not for me (node are in range)
			    if(dst != TOS_NODE_ID){
			    	break;
			    }
			    
				dbg("radio_rec", "node received ACK with token = %d\n", tkn);
				
				// check that it is ACK
				if(type == 3) {
					
					for(i=0; i<32; i++){
						if(sent[i].lock == TRUE){
							if(sent[i].token == tkn){
								sent[i].lock = FALSE;
								break;
							} 
						}
					}	
				}

				

				
				break;
			
			
			case 6:
			case 7:
				
				// get received data packet
				rcm = (radio_route_msg_t*) payload;
		
			   
				src = rcm->src;
				dst = rcm->dst;
				sender = rcm->sender;
				tkn = rcm->token;
				id = rcm->id;
				rtx = rcm->rtx;

				data = rcm->data;
			    type = rcm->type;
			    

			    // generate new packet to forward
			    rcm = (radio_route_msg_t*) call Packet.getPayload(&packet, sizeof(radio_route_msg_t));

				rcm->src = TOS_NODE_ID;
				rcm->dst = dst;
				rcm->sender = sender;
				rcm->token = tkn;
				rcm->rtx = rtx;
				rcm->type = type;
				rcm->data = data;
			    
			    if(type == 3){
			    	generate_send(dst, &packet, 1);
			    } else{
				    generate_send(dst, &packet, 0);
			    }
			    
			
			    break;
			
			
			
			case 8: // server receive packets
			
				rcm = (radio_route_msg_t*) payload;
				
				src = rcm->src;
				sender = rcm->sender;
				tkn = rcm->token;
				data = rcm->data;
			    type = rcm->type;

				dbg("radio_rec", "Server received data packet ---> \t", data);
				
			    // check for duplicates
	    		dup = FALSE;
	    		
	    		for(i=0; i<128; i++){
	    			
	    			if(storage[i].lock == TRUE){
	    				if(storage[i].sender == sender && storage[i].token == tkn){
	    					dup = TRUE;
	    					break;
	    				}
	    			}
				}
				
				
				// non abbiamo un duplicato
				if(dup == FALSE){
					
					
					// salviamo il messaggio
					for(i=0; i<128; i++){
	    			
	        			if(storage[i].lock == FALSE){
	        				storage[i].lock = TRUE;
	        				storage[i].sender = sender;
	        				storage[i].token = tkn;
	        				break;
	        			}
	        			
	        			// check for full storage
			    		if(i==127){
			    			dbg("error", "storage for node 8 is FULL!!!");
			    		}
					}
						
					// print received data
					switch(type) {
				
			        case 0: // humidity
			            dbg_clear("radio_rec", "umidità = %d%", data);
			            break;
			            
			        case 1: // pressure
			            dbg_clear("radio_rec", "pressione = %dhPa", data);
			            break;

			        case 2: // temperature
			            dbg_clear("radio_rec", "temperatura = %d°C", data);
			            break;
	    			}
						
					// send ack back (ack has type 3)

					rcm = (radio_route_msg_t*) call Packet.getPayload(&packet, sizeof(radio_route_msg_t));

					rcm->src = TOS_NODE_ID;
					rcm->dst = sender;
					rcm->sender = TOS_NODE_ID;
					rcm->token = tkn;
					rcm->rtx = 0;
					rcm->type = 3;
					rcm->data = 0;
					
					
					// send ack back
					generate_send(AM_BROADCAST_ADDR, &packet, 1);
						
					// upload stuff
				
					printf("from=%u;to=%u;type=%u;data=%u\n", sender, TOS_NODE_ID, type, data);
					
    				printfflush();

	    			
						

	    		} else {
	    			dbg_clear("radio_rec", "duplicate");
	    		}
			    
			    dbg_clear("radio_rec", " --- token = %d\n", tkn);
			    
				break;
			
			default:
				dbg("dbg", "received something not for me\n");

			}			


		}

	return bufPtr;
	}





	event void TimerStart.fired() {
		dbg("boot", "timer start\n");
	}
	
	





	event void Timer3.fired() {
		
		uint8_t i;
		uint8_t topic;
		int16_t value;
		uint16_t random;
		
		radio_route_msg_t* rcm;
		
		dbg("dbg", "time3 fired IN\n");
		
		// generiamo dato casuale
		
		random = call Random.rand16();
		
		topic = random % 3;
		
		//dbg("random_gen", "numero a caso = %d\n", random);
		//dbg("random_gen", "topic = %d\n", topic);
		
		
		if(random<0){
			random = -random;
		}
		
		
		
		dbg("random_gen", "node %d has generate \t", TOS_NODE_ID);
		
		switch(topic){
		
			case 0: // humidity
				value = random % 100;
				dbg_clear("random_gen", "humidity = %d%", value);
				break;
		
			case 1: // pressure
				value = 1010 + random/10000;
				dbg_clear("random_gen", "pressure = %dhPa", value);
				break;
		
			case 2: // temperature
		
				value = random % 40;
				dbg_clear("random_gen", "temprature = %d°C", value);
				break;
			
		}
		
		dbg_clear("random_gen", "\t with token = %d\n", token);
		
		
		// prepariamo il pacchetto da mandare
		
		rcm = (radio_route_msg_t*) call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
	
		rcm->src = TOS_NODE_ID;
		rcm->dst = 8;
		rcm->sender = TOS_NODE_ID;
		rcm->token = token;
		rcm->rtx = 0;
		rcm->type = topic;
		rcm->data = value;
		
		for(i=0; i<=31; i++){
      		if (sent[i].lock == FALSE) {
      			sent[i].lock = TRUE;
      			sent[i].src = TOS_NODE_ID;
      			sent[i].dst = 8;
      			sent[i].sender = TOS_NODE_ID;
      			sent[i].token = token;
      			sent[i].rtx = 0;
      			sent[i].type = topic;
      			sent[i].data = value;
      			break;
      		}
      		
      		if(i==31){
      			dbg("error", "node buffer for ack is full!\n");
      		}
      	}
      	
      	token++;

		
		generate_send(AM_BROADCAST_ADDR, &packet, 0);
		call Timer1.startOneShot(1000);
		
		
	}
	
	
	
	
	
	
	
	
	event void Timer1.fired() {
        
        uint16_t i;
        uint16_t src;
		uint16_t dst;
		uint16_t sender;
		uint16_t tkn;
		uint16_t id;
		uint16_t rtx;
		uint16_t rtx_old;
		int16_t data;
		uint16_t type;
	
        radio_route_msg_t* rcm;
        
        for(i=0; i<32; i++){
        
        	//
        	if(sent[i].lock == TRUE){
        	

        		tkn = sent[i].token;
        		rtx_old = sent[i].rtx;
        		type = sent[i].type;
        		data = sent[i].data;
        		
        		rtx = rtx_old +1;
        		
				dbg("rto", "packet with token %d will be retransimmet for the %d time\n", tkn, rtx);
				dbg("rto", "RTX old = %d --- RTX new = %d --- TOKEN = %d --- DATA = %d\n",rtx_old, rtx, tkn, data);
				
        		rcm = (radio_route_msg_t*) call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
	
				rcm->src = TOS_NODE_ID;
				rcm->dst = 8;
				rcm->sender = TOS_NODE_ID;
				rcm->token = tkn;
				rcm->rtx = rtx;
				rcm->type = type;
				rcm->data = data;
				
				sent[i].rtx++;
				
				generate_send(AM_BROADCAST_ADDR, &packet, 2);
				
				// if retransmitt a packet 3 times stop wait for ack
				if (rtx >= 3) {
					sent[i].lock = FALSE;
				}

        	}

        }
  
    }


}












