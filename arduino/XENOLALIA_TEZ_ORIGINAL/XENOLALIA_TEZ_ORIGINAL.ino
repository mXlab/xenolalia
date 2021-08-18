// XENOLALIA ESP32 OSC controls - TeZ March 2021 //
/*
    This code controls the hardware contained in the Xenolalia box
      - Pump 1 & 2 
      - Valve 1 & 2 
      - Servo Motor
      - liquid level sensor 
      - Neopixel Ring

    The software receives OSC messages to trigger certain action. See NETWORK.h for a list of possible messages to send.

    In order to make this code work install the ESP32 Arduino board list.T o install the ESP32 board in your Arduino IDE, follow these next instructions:

         1. In your Arduino IDE, go to File> Preferences

         2. Enter https://dl.espressif.com/dl/package_esp32_index.json into the “Additional Board Manager URLs” field as shown in the figure below. 
            Then, click the “OK” button:
            
            Note: if you already have the ESP8266 boards URL, you can separate the URLs with a comma as follows:
              https://dl.espressif.com/dl/package_esp32_index.json, http://arduino.esp8266.com/stable/package_esp8266com_index.json


         3. Open the Boards Manager. Go to Tools > Board > Boards Manager…
         
         4. Search for ESP32 and press install button for the “ESP32 by Espressif Systems“:
         
         5. That’s it. It should be installed after a few seconds.

    The board used in this project is a WEMOS D1 Mini ESP32. Make sure this is the board selected and not a WEMOS LOLIN32 as it will bring OSC issue.

    Before uploading the code to the microcontroller make sure that the SSID and PASSWORD for the wifi are matching the one used by your computer
    You'll find these info in NETWORK.h at the line 5 & 6. These information could have been changed during development.

      Default ssid and password for the project  :
      SSID : Xenolalia
      Password : ************


*/
//------------------------------------------------

//including dependencies
#include <ESP32Servo.h>
#include "Arduino.h"
#include "WiFi.h"
#include <WiFiUdp.h>
#include <OSCMessage.h>
#include <NeoPixelBus.h>
#include "NETWORK.h"



//GLOBAL VARIABLES

static const int servoPin = 19;  // defines pin number for PWM


const uint16_t PixelCount = 24;  //number of pixel on the ring
const uint8_t PixelPin = 23;   // define the pin to communicate with the pixel ring
NeoPixelBus<NeoGrbFeature, Neo800KbpsMethod> strip(PixelCount, PixelPin); //create a pixel object
#define colorSaturation 250

//Colors definition
RgbColor red(colorSaturation, 0, 0);
RgbColor green(0, colorSaturation, 0);
RgbColor blue(0, 0, colorSaturation);
RgbColor yellow(colorSaturation,colorSaturation, 0);
RgbColor white(colorSaturation);
RgbColor black(0);

Servo servo1;  // Create object for servo motor

int pos = 0;    // variable to store the servo position
int maxrotation = 95; //max rotation of the servo in degree
int zpeed = 10; // pause in MS between each step took by the servo
int restime = 100; //rest time between certain steps in the cycle. in MS
int shaketimes = 3; //number of time the tube is shaked in a complete cycle

int liquidLevel = 0; // variable to store the liquid level
int liquidPin = 33; // pin to interface with the liquid level sensor
int liquidThreshold = 500; // maximum liquilLevel value to consider the petridish full

int V2pin = 16; // pin to interface with the valve 1
int V1pin = 17; // pin to interface with the valve 2
int P2pin = 21; //pin to interface with the pump 1
int P1pin = 22; // pin to interface with the pump 2

int pumpTestFlag = 1; // flag used during the pump test

/////////////////////////
//    LED HELPERS      //
/////////////////////////

void pix(int pnum, int xr, int xg, int xb)
{
  /*
    This function set the given pixel to the given color.

    args : 
      int pnum : number of the pixel to modify
      int xr : R value of the RGB color code
      int xg : G value of the RGB color code
      int xb : B value of the RGB color code
  */
  
  strip.SetPixelColor(pnum, RgbColor(xr,xg,xb));
  strip.Show();
  
}

////////////////////////////////////
void strip_black()
{
  /*
    This function turns the whole pixel ring off.  
  */

  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, black);
  }
  strip.Show();
  
}

////////////////////////////////////
void strip_white()
{
  /*
    This function turns the whole pixel ring white.  
  */
  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, white);
  }
  strip.Show();
  
}

////////////////////////////////////
void strip_blue()
{
  /*
    This function turns the whole pixel ring blue.  
  */
  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, blue);
  }
  strip.Show();
  
}

////////////////////////////////////
void strip_red()
{
  /*
    This function turns the whole pixel ring off.  
  */
  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, red);
  }
  strip.Show();
  
}

////////////////////////////////////
void strip_green()
{
  /*
    This function turns the whole pixel ring green.  
  */
  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, green);
  }
  strip.Show();
  
}

////////////////////////////////////
void strip_yellow()
{
  /*
    This function turns the whole pixel ring yellow.  
  */
  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, yellow);
  }
  strip.Show();
  
}

///////////////////////////////
void stripix(int xr, int xg, int xb)
{
  /*
  This function set the whole pixel ring to the color passed in argument

  args:
    int xr: R value of the RGB color to display on the pixel ring 
    int xg: G value of the RGB color to display on the pixel ring 
    int xb: B value of the RGB color to display on the pixel ring 
  
  */
  strip_black();
  
  for(int i=0;i<PixelCount;i++){
     strip.SetPixelColor(i, RgbColor(xr,xg,xb));
     delay(10);
  }
  strip.Show();
  
}



////////////////////////
///   OSC HELPERS    ///
////////////////////////

void oscUpdate() 
{
  /*
  This function update the reception of OSC messages and parses them.
  It points to a callback function if an OSC adress matches one listed below
  */  
  OSCMessage in;
  int size;
  if( (size = Udp.parsePacket()) > 0)
  {
    Serial.println("processing OSC package");
    // parse incoming OSC message
    while(size--) 
    {
      in.fill( Udp.read() );
    }
    
    if(!in.hasError()) 
    {
      in.route("/xeno/pix", on_pix); 
      in.route("/xeno/strip", on_strip); 
      in.route("/xeno/refresh", on_refresh); 
      in.route("/xeno/servo", on_servo);  
      in.route("/xeno/servotest", on_servotest); 
      in.route("/xeno/shake", on_shake); 
      in.route("/xeno/liquid", on_checkLevel); 
      in.route("/xeno/v1", on_v1);  
      in.route("/xeno/v2", on_v2);
      in.route("/xeno/p1", on_p1);  
      in.route("/xeno/p2", on_p2);
      in.route("/xeno/pumpin", on_pumpin);
      in.route("/xeno/pumpout", on_pumpout);
      in.route("/xeno/pumptest", on_pumptest);
    }
     Serial.println("OSC MESSAGE RECEIVED");    
  }
}
///////////////////////////////

void on_pix(OSCMessage &msg, int addrOffset) 
{
    /*
    This function is a callback for when the osc adress /xeno/pix is received
    It fetches the passed  pixel id and RGB values passed in the osc message and 
    turn the specified pixel on calling the pix(pixnum, rr,gg,bb) function. 
    */
    Serial.println("on_pixel");
      
    int pixnum, rr, gg, bb;
    if(msg.isInt(0))
    {
      pixnum = msg.getInt(0);
    }
    if(msg.isInt(1))
    {
      rr = msg.getInt(1);
    }
    if(msg.isInt(2))
    {
      gg = msg.getInt(2);
    }
    if(msg.isInt(3))
    {
      bb = msg.getInt(3);
    }

    pix(pixnum, rr,gg,bb); 
 
}
///////////////////////////////

void on_strip(OSCMessage &msg, int addrOffset)
{
    /*
    This function is a callback for when the osc adress /xeno/strip is received
    It fetches the passed RGB values passed in the osc message and turn the whole pixel ring
     on calling the stripix(rr,gg,bb) function. 
    */
    Serial.println("on_strip");
      
    int rr, gg, bb;
    if(msg.isInt(0))
    {
      rr = msg.getInt(0);
    }
    if(msg.isInt(1))
    {
      gg = msg.getInt(1);
    }
    if(msg.isInt(2))
    {
      bb = msg.getInt(2);
    }

    stripix(rr,gg,bb); 
 
}
///////////////////////////////

void on_pumptest(OSCMessage &msg, int addrOffset) 
{
    /*
    This function is a callback for when the osc adress /xeno/pumptest is received
    It fetches the passed On/Off value in the osc message and start/stop a pump cycle test
    calling the pumpin() and pumpout() functions.
    */

    Serial.println("on_pumptest");
      
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
    }
    else if(msg.isInt(0))
    {
      var = int(msg.getInt(0));
    }

    Serial.println("var: ");
    Serial.println(var);
      
    pumpTestFlag = int(var);
  
    while(pumpTestFlag > 0)
    {   
      pumpout();
      delay(2000);
      
      for(int i=1; i<=2; i++)
      {
         ServoShake();
      }
      delay(2000);
      oscUpdate();
      Serial.println("pumpTestFlag: ");
      Serial.println(pumpTestFlag);
      pumpin();
      delay(2000);
    }  
}
///////////////////////////////

void on_refresh(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/refresh is received.
    It fetches the passed On/Off value in the osc message and start a refresh cycle calling
    the reFresh() function.
  */
  
  Serial.println("on_refresh");    
  float var;
  if(msg.isFloat(0))
  {
    var = msg.getFloat(0);
  }
  else if(msg.isInt(0))
  {
    var = int(msg.getInt(0));
  }
  if (var>0)
  {
    reFresh();
  }
    
}
///////////////////////////////

void on_pumpin(OSCMessage &msg, int addrOffset)
{
  /*
    This function is a callback for when the osc adress /xeno/pumpin is received.
    If the value 1.0 is received in the message it starts a pumpin cycle calling
    the pumpin() function.
  */
  
    Serial.println("on_pumpin");
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
    }
    pumpin();
}
///////////////////////////////


void on_pumpout(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/pumpout is received.
    If the value 1.0 is received in the message it starts a pumpout cycle calling
    the pumpout() function.
  */
    Serial.println("on_pumpout"); 
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
    }
    pumpout();
}
///////////////////////////////

void on_servo(OSCMessage &msg, int addrOffset)
{
  /*
    This function is a callback for when the osc adress /xeno/servo is received.
    It fetches the angle value for the servomotor passed in the osc message and move the 
    motor to the passed angle.
  */
    Serial.println("on_servo");
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
      Serial.println("var: ");
      Serial.println(var);
    }
    int servoangle = int(var);
    servo1.write(servoangle);
    Serial.println("servoangle: ");
    Serial.println(servoangle);
    delay(zpeed);   
}
///////////////////////////////

void on_servotest(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/servotest is received.
    If 1.0 is passed in the OSC message it starts a servo test cycle calling 
    the servo_test() function.
  */    
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
    }

    int rep = int(var);
    Serial.print("on_servotest: ");
    Serial.println(rep);
    for(int i=1; i<=rep; i++)
    {
      ServoTest();
    }   
}
///////////////////////////////

void on_shake(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/shake is received.
    When a message is received at this adress it starts a complete shake cycle
    calling the ServoShake() function the number of time specified in the global variables
  */ 
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0); // var is not used in this fucntion
    }
  
    for(int i=1; i<=shaketimes; i++)
    {
      //ServoTest();
      ServoShake();
    }  
}
///////////////////////////////

void on_checkLevel(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/checkLevel is received.
    When a message is received at this adress it check the liquid level in the petridish
    calling the check_liquid() function.
  */
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0); //doesnt use var in this function
    }
    check_liquid();
  
}
///////////////////////////////

void on_v1(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/v1 is received.
    It turns the vavle 1 On/Off when the OSC message receives 0.0/1.0 by setting the 
    valve pin HIGH or LOW and set the pixel ring to the corresponding color for visual 
    feedback
  */    
    float var;
    int valvestatus = 0;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
      valvestatus = int(var);
    }
    else if(msg.isInt(0))
    {
      valvestatus = msg.getInt(0);
    }

    if(valvestatus == 0)
    {
      digitalWrite(V1pin,LOW);
      strip_black();
    }
    else
    {
      int CL = check_liquid();  // check liquid level sensor 
      if(CL <= liquidThreshold)
      { 
        digitalWrite(V1pin,HIGH);
        strip_blue();
      }
      else
      {  
        digitalWrite(V1pin,LOW);
        strip_yellow(); 
      }     
    }
    Serial.print("v1: ");
    Serial.println(valvestatus);    
}
///////////////////////////////

void on_p1(OSCMessage &msg, int addrOffset) 
{
  
  /*
    This function is a callback for when the osc adress /xeno/p1 is received.
    It turns the pump 1 On/Off when the OSC message receives 0.0/1.0 by setting the 
    pump pin HIGH or LOW 
  */
    float var;
    int pumpstatus = 0;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
      pumpstatus = int(var);
    }
    else if(msg.isInt(0))
    {
      pumpstatus = msg.getInt(0);
    }
    if(pumpstatus == 0)
    {
      digitalWrite(P1pin,LOW);
    }
    else
    {
      digitalWrite(P1pin,HIGH);
    }
    Serial.print("p1: ");
    Serial.println(pumpstatus);
}
///////////////////////////////

void on_p2(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/p2 is received.
    It turns the pump 2 On/Off when the OSC message receives 0.0/1.0 by setting the 
    pump pin HIGH or LOW 
  */
    float var;
    int pumpstatus = 0;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
      pumpstatus = int(var);
    }
    else if(msg.isInt(0))
    {
      pumpstatus = msg.getInt(0);
    }
    if(pumpstatus == 0)
    {
      digitalWrite(P2pin,LOW);
    }
    else
    {
      digitalWrite(P2pin,HIGH);
    }
    Serial.print("p2: ");
    Serial.println(pumpstatus);    
}
///////////////////////////////

void on_v2(OSCMessage &msg, int addrOffset) 
{  
  /*
    This function is a callback for when the osc adress /xeno/v2 is received.
    It turns the vavle 2 On/Off when the OSC message receives 0.0/1.0 by setting the 
    valve pin HIGH or LOW and set the pixel ring to the corresponding color for visual 
    feedback
  */
    float var;
    int valvestatus = 0;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
      valvestatus = int(var);
    }
    else if(msg.isInt(0))
    {
      valvestatus = msg.getInt(0);
    }
    if(valvestatus == 0)
    {
      digitalWrite(V2pin,LOW);
      strip_black();
    }
    else
    {
      digitalWrite(V2pin,HIGH);
      strip_blue();
    }
    Serial.print("v2: ");
    Serial.println(valvestatus);    
}
///////////////////////////////////


////////////////////////
///    HELPERS       ///
////////////////////////

void pumpin()
{
  /*
    This function control pump1 and valve1 to fill the Petri dish 
    until the liquid sensor sends a signal that it's full
  */

    int dishlevel = 1;
    while(dishlevel <= liquidThreshold)
    {
      dishlevel = check_liquid();
      digitalWrite(P1pin,HIGH);
      digitalWrite(V1pin,HIGH);
      delay(250);
      digitalWrite(P1pin,LOW);
      digitalWrite(V1pin,LOW);  
      Serial.println("dishlevel: ");
      Serial.println(dishlevel);
    }
    delay(500);
    strip_black();
}
///////////////////////////////

void pumpout()
{
  /*
    This function start pump 2 and valve 2 for 15 sec to empty the fluid 
    in the petridish
  */
      stripix(0,100,0);
      digitalWrite(P2pin,HIGH);
      digitalWrite(V2pin,HIGH);
      delay(15000);
       strip_black();
      digitalWrite(P2pin,LOW);
      digitalWrite(V2pin,LOW); 
}
///////////////////////////////

void reFresh(){
  /*
    This function refresh the euglena in the petridish
    by pumping out the liquid in the tube, starting a complete
    shake cycle and pumping the liquid back in the petridish
  */   
      pumpout();
      delay(2000);
      for(int i=1; i<=2; i++) //why is this not shaketimes???
      {
         ServoShake();
      }
      delay(2000);      
//      oscUpdate();
      pumpin();
      delay(2000);
      
}
///////////////////////////////

void ServoTest() 
{
  /*
    This function performs a test cycle on the servo motor. 
    It will go from 0 to its max rotation, stop, come back to 0 and stop again.
  */
  for(int posDegrees = 0; posDegrees <= maxrotation; posDegrees++) 
  {
    servo1.write(posDegrees);
  //  Serial.println(posDegrees);
    delay(zpeed);
  }

  delay(restime);

  for(int posDegrees = maxrotation; posDegrees >= 0; posDegrees--) 
  {
    servo1.write(posDegrees);
  //  Serial.println(posDegrees);
    delay(zpeed);
  }

  delay(restime);

}
///////////////////////////////////

void ServoShake() 
{
  /*
    This function control the servo to perform a shake cycle to mix the euglena in the tube.
    It also sets the pixel ring the right color to indicate what's hapenning
  */

  strip_blue();
  
  for(int posDegrees = 0; posDegrees <= maxrotation; posDegrees++) 
  {
    servo1.write(posDegrees);
  //  Serial.println(posDegrees);
    delay(zpeed);
  }

  delay(restime);

  // MID SHAKE
  for(int i=1; i<=7; i++)
  {      
    strip_blue();
    for(int posDegrees = maxrotation; posDegrees >= 50; posDegrees--) 
    {        
      servo1.write(posDegrees);
       delay(zpeed);
    }
    strip_white();  
    for(int posDegrees = 50; posDegrees <= maxrotation; posDegrees++)
    {    
      servo1.write(posDegrees);
      delay(zpeed);
    }
  }
  
  strip_blue();
 
  for(int posDegrees = maxrotation; posDegrees >= 0; posDegrees--) 
  {
    servo1.write(posDegrees);
//  Serial.println(posDegrees);
    delay(zpeed);
  }

  delay(restime);
  strip_black();

}
////////////////////////////////////

int check_liquid() 
{
  /*
    This function verify the amount of liquid in the petridish and return an integer value representing how full it is. 
    If the liquid level is below the threshold is flashed the pixel ring green. If it is over it sets it to red
  */
  
  int myLevel=0;
  for(int i=1; i<=20; ++i)
  {
    liquidLevel = analogRead(liquidPin);
    myLevel += liquidLevel;
    delay(10);
  }
  
  liquidLevel = int(myLevel/20);
    
  Serial.print("liquid level: ");
  Serial.println(liquidLevel);

  if(liquidLevel < liquidThreshold)
  {
    strip_green();
    delay(100);
    strip_black();
  }
  else
  {
    strip_red();
    delay(100);
  }

  return liquidLevel;
}
////////////////////////////////////

void read_liquid() { //NOT USED IN  THE CODE
  liquidLevel = analogRead(liquidPin);
  Serial.print("liquid level: ");
  Serial.println(liquidLevel);
}
////////////////////////////////////

void StripTest()
{
  /*
    This function test the pixel ring cycling through all the defined colors and then turns it off
  */
  strip_black();
  delay(500);
  strip_red();
  delay(500);
  strip_green();
  delay(500);
  strip_blue();
  delay(500);
  strip_white();
  delay(500);
  strip_black();  
}
///////////////////////////////

void setupPins()
{
/*
  This function sets all the necessary pins to the default state of the project
*/  

  pinMode(V1pin, OUTPUT);
  pinMode(V2pin, OUTPUT);
  pinMode(P1pin, OUTPUT);
  pinMode(P2pin, OUTPUT);
  digitalWrite(V1pin,LOW);
  digitalWrite(V2pin,LOW);
  digitalWrite(P1pin,LOW);
  digitalWrite(P2pin,LOW);
  
}
////////////////////////////////////

void setup() 
{

  setupPins();
  Serial.begin(115200);

  // this resets all the neopixels to an off state
  strip.Begin();
  strip.Show();

  servo1.attach(servoPin);  // start the library 

  delay(1000);
  
  WiFiConnect(); // connect to Wifi
//  APConnect(); // create Access Point
  Udp.begin(rxport); // start UDP socket

  StripTest();
  ServoTest();

}

///////////////////////////////////
void loop() {
  
  oscUpdate(); // check for OSC messages

//  int CL = check_liquid();  // check liquid level sensor 
//  Serial.print("liquid level: ");
//  Serial.println(CL);
//  delay(10);

}
