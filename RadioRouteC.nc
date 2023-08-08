
/*
*	IMPORTANT:
*	The code will be avaluated based on:
*		Code design  
*
*/
 
 
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
  
  
  
  
  
  
  bool generate_send (uint16_t address, message_t* packet, uint8_t type){
  /*
  * 
  * Function to be used when performing the send after the receive message event.
  * It store the packet and address into a global variable and start the timer execution to schedule the send.
  * It allow the sending of only one message for each REQ and REP type
  * @Input:
  *		address: packet destination address
  *		packet: full packet to be sent (Not only Payload)
  *		type: payload message type
  *
  * MANDATORY: DO NOT MODIFY THIS FUNCTION
  */
  	if (call Timer0.isRunning()){
  		return FALSE;
  	}else{
  	if (type == 1 && !route_req_sent ){	//route request
  		route_req_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 2 && !route_rep_sent){ //route reply
  	  	route_rep_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 0){	//data
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;	
  	}
  	}
  	return TRUE;
  }
  
  event void Timer0.fired() {
  	/*
  	* Timer triggered to perform the send.
  	* MANDATORY: DO NOT MODIFY THIS FUNCTION
  	*/
  	actual_send (queue_addr, &queued_packet);
  }
  
  
  
  
  bool actual_send (uint16_t address, message_t* packet){
	
	
	  dbg("boot","actual send fired at node %d.\n", TOS_NODE_ID);
	
	 
  }
  
  
  event void Boot.booted() {
    dbg("boot","Application booted.\n");
    dbg("boot","started node %d.\n", TOS_NODE_ID);
    
    call AMControl.start();	//componente ActiveMessageC cominciato
    
  }
  
  
  
  

  event void AMControl.startDone(error_t err) {
	
	
    if (err == SUCCESS) {
      dbg("radio","Radio on on node %d!\n", TOS_NODE_ID);
      
      switch(TOS_NODE_ID) {
			
			case 1:
			case 2:
			case 3:
			case 4:
			case 5:
				call Timer3.startPeriodic(TOS_NODE_ID * 1000);
				break;
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
	
	dbg("boot", "receive.receive\n");
    
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
		dbg("boot", "send done\n");
    }



	event void TimerStart.fired() {
		
		dbg("boot", "timer start\n");
	}
	
	
	
	event void Timer3.fired() {
		
		uint8_t topic;
		int16_t value;
		
		
		random = call Random.rand16();
		// dbg("boot", "numero a caso = %d\n", random);
		
		topic = random % 3;
		dbg("boot", "numero a caso = %d\n", random);
		dbg("boot", "topic = %d\n", topic);
		
		
		switch(topic){
		
		case 0: // humidity
			value = (random*100)/65535;
			dbg("boot", "umidità = %d%\n", value);
			break;
		
		case 1: // pressure
			value = 1010 + random/10000;
			dbg("boot", "pressione = %dhPa\n", value);
			break;
		
		case 2: // temperature
		
			value = (random*100)/65535;
			value = value/2 -10;
			dbg("boot", "temperatura = %dC\n", value);
			break;
			
		}
		
		dbg("boot", "\n");
		
	}

}





