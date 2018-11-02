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
#ifdef ARDUINO_ARCH_ESP32
#include <ESP32Servo.h>
#include <WiFi.h>
#else
#include <ESP8266WiFi.h>
#include <Servo.h>
#endif

#include <WiFiUdp.h>
#include <OSCMessage.h>
#include <FastLED.h>

// Config file needs to be edited to match network settings.
#include "Config.h"

// Servomotor.

#ifdef ARDUINO_ARCH_ESP32
#define SERVO_PIN 2
#else
#define SERVO_PIN 0
#endif
Servo servo;
int sangle = 90; // initial servo angle

// Network.
WiFiUDP Udp;                                // A UDP instance to let us send and receive packets over UDP
IPAddress thisip;

// Pixel strip control.
#define N_PIXELS 30 // how many neopixels in your strip?
#define DATA_PIN 4 // green wire
#define CLOCK_PIN 5 // yellow wire
#define COLOR_ORDER BGR //  (adjust for RGB)

// This is an array of leds.  One item for each led in your strip.
CRGB leds[N_PIXELS];

// Default/base brightness of pixels.
#define DEFAULT_BRIGHTNESS 128

// Servo motor min/max angles.
#define SERVO_MIN 12
#define SERVO_MAX 180

void setup()
{
  // Init serial.
  Serial.begin(115200);
  while (!Serial); // wait for serial attach

  // Init outputs.
  pinMode(LED_BUILTIN, OUTPUT);     // Initialize the LED_BUILTIN pin as an output
  servo.attach(SERVO_PIN); // attach servo to WEMOS pin D3

  // Init LED strip.
  Serial.println("Starting LED strip");
  FastLED.addLeds<APA102, DATA_PIN, CLOCK_PIN, COLOR_ORDER>(leds, N_PIXELS);
  FastLED.setBrightness(DEFAULT_BRIGHTNESS);

  for (int i=0; i<N_PIXELS; i++)
    leds[i] = CRGB::White;
  FastLED.show();

  // Init network.
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
#ifndef ARDUINO_ARCH_ESP32
  Serial.print("Local port: ");
  Serial.println(Udp.localPort());
#endif

  // Clear LED strip.
  for (int i=0; i<N_PIXELS; i++)
    leds[i] = CRGB::Black;
  FastLED.show();

  moveServo(0);
  delay(500);
  moveServo(180);
  delay(500);
  moveServo(0);  

  Serial.println("Done");
  
  // Blink indicator led.
  digitalWrite(LED_BUILTIN, LOW);   // Turn the LED on (Note that HIGH is the voltage level
  delay(1000);
  digitalWrite(LED_BUILTIN, HIGH);   // Turn the LED off (Note that LOW is the voltage level
}

/////////////////////////////////////
void loop()
{
  receiveOsc();
  delay(1);
}


/////////////////////////////////////
/// READ OSC MESSAGES ///
void receiveOsc() {
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
      in.route("/xeno/pixels/all",  onXenoPixelsAll);
      in.route("/xeno/pixels/one",  onXenoPixelsOne);
      in.route("/xeno/pixels/brightness",  onXenoPixelsBrightness);
      in.route("/xeno/shutter", onXenoShutter);
     }
  } // if
}

void onXenoPixels(OSCMessage &msg, int addrOffset, bool allPixels) {
  int arg = 0;
  int pixelIndex = (-1);
  if (!allPixels) {
    pixelIndex = msg.getInt(arg++);
  }

  if (msg.match("/rgb", addrOffset)) {
    Serial.println("RGB");
    int r = msg.getInt(arg++);
    int g = msg.getInt(arg++);
    int b = msg.getInt(arg++);

    if (allPixels) {
      for (int i=0; i<N_PIXELS; i++)
        leds[i].setRGB(r, g, b);
    }
    else {
      leds[pixelIndex].setRGB(r, g, b);
    }
  }
  else if (msg.match("/hsv", addrOffset)) {
    Serial.println("HSV");
    int h = msg.getInt(arg++);
    int s = msg.getInt(arg++);
    int v = msg.getInt(arg++);
    if (allPixels) {
      for (int i=0; i<N_PIXELS; i++)
        leds[i].setHSV(h, s, v);
    }
    else {
      leds[pixelIndex].setHSV(h, s, v);
    }
  }
  else if (msg.match("/clear", addrOffset)) {
    Serial.println("CLEAR");
    if (allPixels) {
      for (int i=0; i<N_PIXELS; i++)
        leds[i] = CRGB::Black;
    }
    else {
      leds[pixelIndex] = CRGB::Black;
    }
  }
  else {
    Serial.println("Error: no match.");
  }

  // Update leds.
  FastLED.show();
}

void onXenoPixelsAll(OSCMessage &msg, int addrOffset) {
  onXenoPixels(msg, addrOffset, true);
}

/////////////////////////////////////
void onXenoPixelsOne(OSCMessage &msg, int addrOffset) {
  onXenoPixels(msg, addrOffset, false);
}

void onXenoPixelsBrightness(OSCMessage &msg, int addrOffset) {
  Serial.println("Adjust brightness");
  int brightness = msg.getInt(0);
  FastLED.setBrightness(brightness);
  FastLED.show();
}

#define DEGREE_PER_SECOND 40
const int MILLIS_PER_DEGREE = 1000 / DEGREE_PER_SECOND;
// Move servo to angle.
void moveServo(int angle) {
  angle = constrain(angle, SERVO_MIN, SERVO_MAX);
  int currentAngle = servo.read();
  int dir = (angle > currentAngle ? +1 : -1);
  for (; currentAngle != angle; currentAngle += dir) {
    servo.write(currentAngle);
    delay(MILLIS_PER_DEGREE);
  }
  Serial.println("servo angle: " + String(angle));  
}

void onXenoShutter(OSCMessage &msg, int addrOffset) {
  if( msg.isInt(0)) {
    int angle = msg.getInt(0);
    moveServo(angle);
//    Serial.println("servo angle: " + String(angle));  
  }
}
