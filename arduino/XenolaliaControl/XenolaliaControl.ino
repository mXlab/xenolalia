/*
 * Xenolalia Light + motors control
 *
 * (c) TeZ + Sofian Audry
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
int servoPin = 0; // WEMOS pin D3
Servo Servo1; 
int Sangle = 90; // initial servo angle
///
#include <ESP8266WiFi.h>
#include <WiFiUdp.h>
#include <OSCMessage.h>
#include <Metro.h>
#include <NeoPixelBus.h>
//#include <String.h>
///
const char* ssid = "OPTONET";  // your WiFi network SSID
const char* pass = "9F69D465B2EE"; // your WiFi network password
int device_id = -1;
int WIP[]={0,0,0,0};
WiFiUDP Udp;                                // A UDP instance to let us send and receive packets over UDP
const IPAddress dest(192, 168, 10, 255);
const unsigned int rxport = 12345;          // remote port to receive OSC
const unsigned int txport = 54321;        // local port to listen for OSC packets (actually not used for sending)


IPAddress thisip;
int WID = 23; // ID# OF YOUR WEMOS 


const uint16_t PixelCount = 20; // how many neopixels in your strip?
const uint8_t PixelPin = 2; // ignored for Esp8266 - Wemos, it uses GPIO 2 = PIN D4 (UART MODE)

#define colorSaturation 128

// UART MODE, HIGH SPEED
NeoPixelBus<NeoGrbFeature, NeoEsp8266Uart800KbpsMethod> strip(PixelCount, PixelPin);


RgbColor red(colorSaturation, 0, 0);
RgbColor green(0, colorSaturation, 0);
RgbColor blue(0, 0, colorSaturation);
RgbColor white(colorSaturation);
RgbColor black(0);

HslColor hslRed(red);
HslColor hslGreen(green);
HslColor hslBlue(blue);
HslColor hslWhite(white);
HslColor hslBlack(black);

bool INLED = false;


void setup()
{

    pinMode(LED_BUILTIN, OUTPUT);     // Initialize the LED_BUILTIN pin as an output

    Servo1.attach(servoPin); // attach servo to WEMOS pin D3
       
    Serial.begin(115200);
    while (!Serial); // wait for serial attach

    // init network
    Serial.println();
    Serial.print("Connecting to ");
    Serial.println(ssid);
    
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
    
    Serial.println("Starting UDP");
    Serial.print("Local port: ");
    Serial.println(Udp.localPort());
    
    device_id = WID; // thisip[3];
    //
    

    // this resets all the neopixels to an off state
    strip.Begin();
    strip.Show();
    
    
    for (int i=0; i< PixelCount; ++i){
        strip.SetPixelColor(i, red);
    }   
    strip.Show(); 
    delay(500);
    
    for (int i=0; i< PixelCount; ++i){
        strip.SetPixelColor(i, green);
    }   
    strip.Show(); 
    delay(500);   

    for (int i=0; i< PixelCount; ++i){
        strip.SetPixelColor(i, blue);
    }   
    strip.Show(); 
    delay(500);

     for (int i=0; i< PixelCount; ++i){
        strip.SetPixelColor(i, hslBlack);
    }   
    strip.Show(); 
    delay(100);



    Servo1.write(0); 
    delay(1000);
    Servo1.write(90); 
    delay(1000);
    Servo1.write(180); 
    delay(1000);
    Servo1.write(0); 
    delay(1000);


   digitalWrite(LED_BUILTIN, LOW);   // Turn the LED on (Note that HIGH is the voltage level
   delay(1000);
   digitalWrite(LED_BUILTIN, HIGH);   // Turn the LED off (Note that LOW is the voltage level

    
}

/////////////////////////////////////
void loop()
{

    osc_message_pump();


}



/////////////////////////////////////
/// READ OSC MESSAGES ///
void osc_message_pump() {  
  OSCMessage in;
  int size;

  if( (size = Udp.parsePacket()) > 0)
  {
    Serial.println("processing OSC package");
    // parse incoming OSC message
    while(size--) {
      in.fill( Udp.read() );
    }

    if(!in.hasError()) {
      in.route("/xenopixels", on_xenopixels);
      in.route("/xenoshutter", on_xenoshutter);
     }
  } // if

   INLED = !(INLED);
   if(INLED){
      digitalWrite(LED_BUILTIN, LOW);   // Turn the LED on (Note that LOW is the voltage level
   }else{
     digitalWrite(LED_BUILTIN, HIGH);   // Turn the LED on (Note that LOW is the voltage level
   }

}

/////////////////////////////////////
void on_xenopixels(OSCMessage &msg, int addrOffset) {

   int osc_red, osc_green, osc_blue;
  
  if( msg.isInt(0)) {
    osc_red = msg.getInt(0);
    osc_green = msg.getInt(1);
    osc_blue = msg.getInt(2);   
  }

  Serial.println("osc_color: " + String(osc_red) + " " + String(osc_green) + " " + String(osc_blue));
  
 

  RgbColor osc_color(osc_red, osc_green, osc_blue);

      for (int i=0; i< PixelCount; ++i){
        strip.SetPixelColor(i, osc_color);
    }  
        strip.Show(); 

    // delay(20);
}


/////////////////////////////////////
void on_xenoshutter(OSCMessage &msg, int addrOffset) {

 // myservo.attach(servoPin, 500, 2400); 

 // delay(50);
  
  if( msg.isInt(0)) {
    Sangle = msg.getInt(0);  
  }

  if (Sangle == 0){ Sangle = 12;}

  Serial.println("servo angle: " + String(Sangle));

  if (Sangle <=12) { Sangle = 12; }
  
  Servo1.write(Sangle); // set the servo position to the given angle
  
  delay(100);

 // myservo.detach();   // detaches the servo

}



