#include <osc.hpp>

#include<pins.h>
#include <WiFi.h>
#include <OSCMessage.h>

#include <xenolalia.h> 

void host_handshake(OSCMessage &msg){
  
  if(msg.isInt(0) == 1){
   
    Serial.println("Host asking for shake");
    osc::send("/handshake", true);
    osc::hand_shaked = true;

  }
}

void reply_heartbeat(OSCMessage &msg){
  
  if(msg.isInt(0) && msg.getInt(0)){

    Serial.println("received heartbeat");
    osc::send("/heartbeat",1);

  }
}

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


  osc::send("/xeno/apparatus/refreshed" ," ");
  
  if (is_float_or_int(msg))
  {
    xenolalia::cycle();
    osc::send("debug", "Started refresh cycle");
  }
 
}

void test_hardware(OSCMessage &msg){

  if (is_float_or_int(msg))
  {
    osc::send("debug", "Testing all the hardware");
    xenolalia::test();
  }
}

void drain(OSCMessage &msg){
 
  osc::send("debug", "Draining tube");

  xenolalia::drain();
}

void fill(OSCMessage &msg){
 
  osc::send("debug", "Filling tube");

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


  void connectToWiFi(const char * ssid, const char * pwd){

  // delete old config
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

  void initUDP(){
    
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
       
        msg.dispatch("/handshake", host_handshake);
        msg.dispatch("/heartbeat_reply", reply_heartbeat);
        msg.dispatch("/xeno/test_hardware", test_hardware);
        msg.dispatch("/xeno/refresh",start_cycle);
        msg.dispatch("/xeno/drain", drain);
        msg.dispatch("/xeno/fill", fill);
      }
      else{
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

  boolean WifiConnected() {
  return WiFi.status() == WL_CONNECTED;
}

  void WiFiCheckConnection() 
  {
    if (!WifiConnected()) {
      // First try to disconnect and reconnect.
      Serial.println("Disconnected");
      WiFi.disconnect();
      WiFi.reconnect();
      delay(8000);

      // If still disconnected: reboot.
      if (!WifiConnected()) {
      Serial.println("Reboot");
        ESP.restart();
      }
    }
  }
}//namespace osc

