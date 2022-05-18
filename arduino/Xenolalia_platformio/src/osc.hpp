#pragma once 
#include <WiFiUdp.h>

/** @brief declaration file of wifi connection and osc protocol
 */

//forward delcarations
class IPAddress;
class WiFiUDP;
class OSCMessage;


namespace osc{

    extern const char* ssid;
    extern const char* pass;
    extern IPAddress local_IP;
    extern IPAddress host_IP;
    extern IPAddress gateway;
    extern IPAddress subnet;
    extern  WiFiUDP udp;
    extern bool connected;
    extern bool hand_shaked;
    extern int reply_port;
    extern int incoming_port; 


    /**
     * @brief connects to the wifi network usingthe provided informations
     * 
     * @param ssid network name to connect to
     * @param pwd  password of the network
     */
    void connect_to_wifi(const char * ssid, const char * pwd);
    

    /** @brief initialize udp connection 
     */
    void init_udp();

    /** @brief OSC protocol update loop. Verify if there's an incoming message add points to the right callback  
    */
    void update();

    /** @brief Verify if mcu is still connected to wifi. Reboot if connection is lost
     */
    void wifi_check_connection();

    /** @brief return true if mcu is connected to wifi
     */
    boolean is_wifi_connected();


    /**
     * @brief send and osc message to host
     * @param adress osc adress
     * @param val char*
     */
    void send( const char* adress, const char* val );

    /**
     * @brief send and osc message to host
     * @param adress osc adress
     * @param val bool
     */
    void send( const char* adress, const bool val );

    /**
     * @brief send and osc message to host
     * @param adress osc adress
     * @param val int
     */
    void send( const char* adress, const int val );

    void send( const char* adress );
}//namespace osc
