

#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H


typedef nx_struct radio_route_msg {
	
	nx_uint16_t src;
	nx_uint16_t dst;
	nx_uint16_t sender;
	nx_uint16_t next_hop;
	nx_uint16_t token;
	nx_uint16_t id;
	nx_uint16_t rtx;
	
	nx_uint16_t type;
	nx_uint16_t data;
	
} radio_route_msg_t;


enum {
  AM_RADIO_COUNT_MSG = 10,
};


#endif
