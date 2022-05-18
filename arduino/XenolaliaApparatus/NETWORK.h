
////////////////////////
///     NETWORKS     ///
////////////////////////
/*
  This File contains all the code handling the network connection
*/

//vv SET THE NETWORK INFORMATIONS HERE vv
const char* ssid = "Xenolalia";
const char* pass = "EuglenaNeuron";

WiFiServer server(80);

// it wil set the static IP address to 192, 168, 10, 23
IPAddress local_IP(192, 168, 0, 102); 
//it wil set the gateway static IP address to 192, 168, 10,1
IPAddress gateway(192, 168, 0, 1); 
IPAddress subnet(255, 255, 0, 0); //not used



WiFiUDP Udp;                                // A UDP instance to let us send and receive packets over UDP
const IPAddress dest(192, 168, 0, 101);  //pi ip adress

const unsigned int rxport = 7000;          // remote port to receive OSC
const unsigned int txport = 7001;        // local port to listen for OSC packets (actually not used for sending)

int WID = 1; // ID# OF THIS BOARD

////////////////////////////////
void APConnect(){ //NOT USED IN THE CODE

  Serial.println("Configuring access point...");

  WiFi.mode(WIFI_AP);
  WiFi.softAP(ssid, pass);
  Serial.println("Wait 100 ms for AP_START...");
  delay(100);


  
  Serial.println("Set softAPConfig");
  IPAddress Ip(192, 168, 10, 23);
  IPAddress NMask(255, 255, 255, 0);
  WiFi.softAPConfig(Ip, Ip, NMask);
  
  IPAddress myIP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(myIP);
}

////////////////////////////////
IPAddress WiFiConnect()
{
  /*
    This function takes the necessary steps to connect the micro controller to the wifi network
  */
      // CONNECT TO WIFI NETWORK
  // delete old config
  WiFi.disconnect(true);

  // Configures static IP address
  if (!WiFi.config(local_IP, gateway, subnet)) {
    Serial.println("STA Failed to configure");
  }
  
  WiFi.begin(ssid, pass); 
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("WiFi connected");  
  Serial.println("IP address: ");
  IPAddress thisip = WiFi.localIP();
  Serial.println( thisip );

  Udp.begin(rxport);

  return thisip;
}

boolean WifiConnected() {
  return WiFi.status() == WL_CONNECTED;
}

void WiFiCheckConnection() {
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


// END
