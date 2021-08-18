//const char* ssid     = "your_wifi_ssid";
//const char* pass = "your_wifi_password";

// custom router
const char* ssid = "Xenolalia";
const char* pass = "************";

WiFiServer server(80);

// it wil set the static IP address to 192, 168, 10, 23
IPAddress local_IP(192, 168, 1, 23);
//it wil set the gateway static IP address to 192, 168, 10,1
IPAddress gateway(192, 168, 1, 1);

// Following three settings are optional
IPAddress subnet(255, 255, 0, 0);
IPAddress primaryDNS(8, 8, 8, 8); 
IPAddress secondaryDNS(8, 8, 4, 4);

WiFiUDP Udp;                                // A UDP instance to let us send and receive packets over UDP
// const IPAddress dest(192, 168, 8, 255);
const unsigned int rxport = 54321;          // remote port to receive OSC
const unsigned int txport = 12345;        // local port to listen for OSC packets (actually not used for sending)
IPAddress thisip;

int WID = 1; // ID# OF THIS BOARD

////////////////////////////////
void APConnect(){

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
void WiFiConnect(){

      // CONNECT TO WIFI NETWORK
  WiFi.begin(ssid, pass); 
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("WiFi connected");  
  Serial.println("IP address: ");
  thisip = WiFi.localIP();
  Serial.println( thisip );

  Udp.begin(rxport);
}

// END
