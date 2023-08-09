
 
#include "Timer.h"
#include "RadioRoute.h"


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
    uint16_t time_delays[7]={61,173,267,371,479,583,689}; //Time delay in milli seconds


    bool route_req_sent=FALSE;
    bool route_rep_sent=FALSE;


    bool locked;

    bool actual_send (uint16_t address, message_t* packet);
    bool generate_send (uint16_t address, message_t* packet, uint8_t type);

    uint16_t random;
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






    bool generate_send (uint16_t address, message_t* packet, uint8_t type){


        dbg("dbg", "generate send IN \n");


        if (call Timer0.isRunning()){
            dbg("dbg", "BAD generate send OUT cuz timer0 is running \n\n");
            return FALSE;
        }else{
            if (type == 0){		//data
            	queued_packet = *packet;
                queue_addr = address;
                call Timer0.startOneShot( time_delays[TOS_NODE_ID-1]  );
                
            }else if (type == 1){ 		//ack
            	queued_packet = *packet;
                queue_addr = address;
                call Timer0.startOneShot( time_delays[TOS_NODE_ID-1]  );
                
            }
        }
        dbg("dbg", "generate send OUT OK\n\n");
        return TRUE;
    }
  




  
    event void Timer0.fired() {
        actual_send (queue_addr, &queued_packet);
    }
  



  
  
    bool actual_send (uint16_t address, message_t* packet){

        dbg("dbg", "actual send IN\n");

        if (locked) {
            dbg("dbg", "BAD actual send OUT cuz locked\n\n");
            return FALSE;
        }
        else {
            if (call AMSend.send(address, packet, sizeof(radio_route_msg_t)) == SUCCESS) {
                dbg("radio_send", "Sending packet");
                locked = TRUE;
                dbg_clear("radio_send", " at time %s \n", sim_time_string());
                dbg("dbg", "actual send OUT ok\n\n");
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
	    	dbg("dbg", "SUPER BAD in send done");
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
			
			if(TOS_NODE_ID == 2){
			
				call Timer3.startPeriodic(time_delays[TOS_NODE_ID-1]);
			
			}
			
			if(TOS_NODE_ID == 5){
			
				call Timer3.startOneShot(time_delays[TOS_NODE_ID-1]);
			
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





  
    event void Timer1.fired() {
        dbg("boot", "timer1\n");
    }






    event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    
    uint16_t data;
    uint16_t type;

    radio_route_msg_t* rcm;

    dbg("dbg", "receive IN\n");

        if (len != sizeof(radio_route_msg_t)) {
            return bufPtr;
        }

        else{

            rcm = (radio_route_msg_t*) payload;
            data = rcm->data;
            type = rcm->type;

            switch(type) {

                case 0: // humidity
                    dbg("radio_rec", "umidità = %d%\n", data);
                    break;
                case 1: // pressure
                    dbg("radio_rec", "pressione = %dhPa\n", data);
                    break;

                case 2: // temperature
                    dbg("radio_rec", "temperatura = %d°C\n", data);
                    break;
            }

        }
        
        dbg("dbg", "receive OUT\n\n");
        return bufPtr;

    }







	event void TimerStart.fired() {
		dbg("boot", "timer start\n");
	}
	
	





	event void Timer3.fired() {
		
		uint8_t i;
		uint8_t topic;
		int16_t value;
		
		radio_route_msg_t* rcm;
		
		dbg("dbg", "time3 fired IN\n");
		
		// generiamo dato casuale
		
		random = call Random.rand16();
		// dbg("boot", "numero a caso = %d\n", random);
		
		topic = random % 3;
		dbg("random_gen", "numero a caso = %d\n", random);
		dbg("random_gen", "topic = %d\n", topic);
		
		
		switch(topic){
		
			case 0: // humidity
				value = (random*100)/65535;
				dbg("random_gen", "umidità = %d%\n", value);
				break;
		
			case 1: // pressure
				value = 1010 + random/10000;
				dbg("random_gen", "pressione = %dhPa\n", value);
				break;
		
			case 2: // temperature
		
				value = (random*100)/65535;
				value = value/2 -10;
				dbg("random_gen", "temperatura = %dC\n", value);
				break;
			
		}
		
		dbg("random_gen", "\n");
		
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
      			dbg("dbg", "I=%d\n", i);
      			break;
      		}
      	}
      	
      	token++;

		
		generate_send(AM_BROADCAST_ADDR, &packet, 0);
		
		dbg("dbg", "time3 fired OUT\n\n");
		
	}

}
