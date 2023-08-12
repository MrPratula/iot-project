
#define NEW_PRINTF_SEMANTICS
#include "RadioRoute.h"


// add this in makefile
//CFLAGS += -I$(TOSDIR)/lib/printf
//CFLAGS += -DNEW_PRINTF_SEMANTICS


configuration RadioRouteAppC {
}


implementation {
/****** COMPONENTS *****/
    components MainC, RadioRouteC as App;

    //add the other components here

    components new TimerMilliC() as Timer0;
    components new TimerMilliC() as Timer1;

    components new TimerMilliC() as TimerStart;
    components new TimerMilliC() as Timer3;

    components RandomC;


    components new AMSenderC(AM_RADIO_COUNT_MSG);
    components new AMReceiverC(AM_RADIO_COUNT_MSG);
    components ActiveMessageC;
    
    components SerialPrintfC;
    components SerialStartC;


    /****** INTERFACES *****/
    //Boot interface
    App.Boot -> MainC.Boot;

    /****** Wire the other interfaces down here *****/
    App.Timer0 -> Timer0;
    App.Timer1 -> Timer1;

    App.Timer3 -> Timer3;
    App.TimerStart -> TimerStart;


    App.AMControl -> ActiveMessageC;
    App.Receive -> AMReceiverC;
    App.AMSend -> AMSenderC;
    App.Packet -> AMSenderC;

    App.Random -> RandomC;

}

