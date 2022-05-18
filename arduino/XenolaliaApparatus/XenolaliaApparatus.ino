///////////////////////////////////////////////////
// XENOLALIA ESP32 OSC controls - TeZ March 2021 //
///////////////////////////////////////////////////
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
char buff[64];


#include "LED_HELPERS.h"
#include "HELPERS.h"
#include "OSC_HELPERS.h"
#include "OTA.h"


void setup() 
{
  // Serial.
  Serial.begin(115200);

  // Pins.
  setupPins();

  // Reset all the neopixels to an off state.
  strip.Begin();
  strip.Show();

  // Servomotor.
  servo1.attach(servoPin);  // start the library 

  // Start wifi.
  IPAddress ip = WiFiConnect(); // connect to Wifi
//  APConnect(); // create Access Point
  
  Udp.begin(rxport); // start UDP socket

  // Initialize Over-The-Air programming comm.
  initOTA(ip[3]);

  // Run LED strip test to show the program is started.
  StripTest();

  // Wait a little.
  delay(1000);
}

///////////////////////////////////
void loop() {
  // Call Over-The-Air update.
  updateOTA();

  // Make sure connection is still on (and troubleshoot it if not).
  WiFiCheckConnection();

  // Check for OSC messages
  oscUpdate();

//  int CL = check_liquid();  // check liquid level sensor 
//  Serial.print("liquid level: ");
//  Serial.println(CL);
//  delay(10);

}
