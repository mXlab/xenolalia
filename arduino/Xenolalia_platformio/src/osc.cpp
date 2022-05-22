#include "osc.hpp"
#include "pins.h"
#include <WiFi.h>
#include <OSCMessage.h>
#include "xenolalia.h"

/** @brief implementation file of wifi connection and osc protocol
 */

/*
  OSC ADRESS YOU CAN USE
       "/xeno/test_hardware" -> test_hardware();
       "/xeno/refresh" -> start_cycle();
       "/xeno/drain" -> drain();
       "/xeno/fill" -> fill();
*/

//OSC CALLBACKS

/**
 * @brief verify if the passed message contains int or float
 * @param msg osc message to inspect
 * @return true if the int or float is not zero
 */
bool is_float_or_int(OSCMessage &msg){
  

  if(msg.isFloat(0))
  {
    float var{msg.getFloat(0)};
    if(var == 0.0) return false;

  }
  else if(msg.isInt(0))
  {
    int var{msg.getInt(0)};
    if(var == 0) return false;
  }

  return true;
}

void start_cycle(OSCMessage &msg){

  osc::send("/xeno/handshake");
  
  if (is_float_or_int(msg))
  {
    osc::send("/debug", "Started refresh cycle");
    xenolalia::cycle();
    osc::send("/xeno/apparatus/refreshed");
  }
 
}

void test_hardware(OSCMessage &msg){
  
  osc::send("/xeno/handshake");
  if (is_float_or_int(msg))
  {
    osc::send("/debug", "Testing all the hardware");
    xenolalia::test();
  }
}

void drain(OSCMessage &msg){
 
  osc::send("/xeno/handshake");
  osc::send("/debug", "Draining tube");
  xenolalia::drain();
}

void fill(OSCMessage &msg){

  osc::send("/xeno/handshake");
  osc::send("/debug", "Filling tube");
  xenolalia::fill();
}

namespace osc
{
  const char* ssid {"Xenolalia"};
  const char* pass {"EuglenaNeuron"};
  bool connected{false};
  bool hand_shaked{false};

  int reply_port{7001};
  int incoming_port{7000};

  IPAddress local_IP(192, 168, 0, 102); //mcu adress ip
  IPAddress host_IP{};

  IPAddress gateway(10, 0, 0, 1);
  IPAddress subnet(255, 255, 0, 0);
  WiFiUDP udp{};


  void connect_to_wifi(const char * ssid, const char * pwd)
  {

    WiFi.disconnect(true);

      // Configures static IP address
      if (!WiFi.config(local_IP, gateway, subnet)) {
          
          Serial.println("STA Failed to configure");    
      }

      WiFi.begin(ssid, pwd);

      
      while (WiFi.status() != WL_CONNECTED) {
          delay(500);
          Serial.print(".");
      }
      
      Serial.println("");
      Serial.println("WiFi connected");
}

  void init_udp(){
    
    Serial.println("Starting UDP");    
    udp.begin(incoming_port);
    Serial.print("IP address: "); 
    Serial.println(WiFi.localIP());
    connected = true;
}

  void send( const char* adress, const bool val ){
    OSCMessage mess(adress);
    mess.add(val);

    udp.beginPacket(udp.remoteIP(), osc::reply_port);
    mess.send(udp);
    udp.endPacket();
    mess.empty();
  }

void send( const char* adress ){
    OSCMessage mess(adress);
    
    udp.beginPacket(udp.remoteIP(), osc::reply_port);
    mess.send(udp);
    udp.endPacket();
    mess.empty();
  }

  void send( const char* adress, const char* val ){
    OSCMessage mess(adress);
    mess.add(val);

    udp.beginPacket(udp.remoteIP(), osc::reply_port);
    mess.send(udp);
    udp.endPacket();
    mess.empty();
  }

  void send( const char* adress, const int val ){
    OSCMessage mess(adress);
    mess.add(val);

    udp.beginPacket(udp.remoteIP(), osc::reply_port);
    mess.send(udp);
    udp.endPacket();
    mess.empty();
  }
  
  void update()
  {
    //OSC Routine
    //Tried to wrap this in a class and in a namespace and it makes the mcu crash for unknown reasons
    OSCMessage msg;
    int size = udp.parsePacket();
     
    if (size > 0) {

      Serial.println("Message received");
      
      while (size--) {
        msg.fill(udp.read());
      }

      if (!msg.hasError()) {
       
        msg.dispatch("/xeno/test_hardware", test_hardware);
        msg.dispatch("/xeno/refresh",start_cycle);
        msg.dispatch("/xeno/drain", drain);
        msg.dispatch("/xeno/fill", fill);
      }
      else
      {
        switch(msg.getError()){
          case BUFFER_FULL:
          Serial.println("OSC MESSAGE ERROR : BUFFER_FULL");
          break;

          case INVALID_OSC:
          Serial.println("OSC MESSAGE ERROR : INVALID_OSC");
          break;

          case ALLOCFAILED:
          Serial.println("OSC MESSAGE ERROR : ALLOCFAILED");
          break;

          case INDEX_OUT_OF_BOUNDS:
          Serial.println("OSC MESSAGE ERROR : INDEX_OUT_OF_BOUNDS");
          break;

          case OSC_OK:
          Serial.println("OSC MESSAGE ERROR : OSC_OK");

          break;

        }
      } 
    }
  }

  boolean is_wifi_connected() {
  return WiFi.status() == WL_CONNECTED;
}

  void wifi_check_connection() 
  {
    if (!is_wifi_connected()) {
      // First try to disconnect and reconnect.
      Serial.println("Disconnected");
      WiFi.disconnect();
      WiFi.reconnect();
      delay(8000);

      // If still disconnected: reboot.
      if (!is_wifi_connected()) {
      Serial.println("Reboot");
        ESP.restart();
      }
    }
  }
}//namespace osc

