#pragma once 
#include <WiFiUdp.h>

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
    void connectToWiFi(const char * ssid, const char * pwd);
    

    /** @brief initialize udp connection 
     */
    void initUDP();

    /** @brief OSC protocol update loop. Verify if there's an incoming message add points to the right callback  
    */
    void update();

    /** @brief Verify if mcu is still connected to wifi. Reboot if connection is lost
     */
    void WiFiCheckConnection();

    /** @brief return true if mcu is connected to wifi
     */
    boolean WifiConnected();


    void send( const char* adress, const char* val );
    void send( const char* adress, const bool val );
    void send( const char* adress, const int val );

}//namespace osc
