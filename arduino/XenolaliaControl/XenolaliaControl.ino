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
#include <Servo.h>
#include <ESP8266WiFi.h>
#include <WiFiUdp.h>
#include <OSCMessage.h>
#include <Metro.h>
#include <NeoPixelBus.h>

// Config file needs to be edited to match network settings.
#include "Config.h"

// Servomotor.
#define SERVO_PIN 0
Servo servo;
int sangle = 90; // initial servo angle

// Network.
WiFiUDP Udp;                                // A UDP instance to let us send and receive packets over UDP
IPAddress thisip;

// Pixel strip control.
#define N_PIXELS 20 // how many neopixels in your strip?
#define PIXEL_PIN 4 // ignored for Esp8266 - Wemos, it uses GPIO 2 = PIN D4 (UART MODE)

#define COLOR_SATURATION 128

// UART MODE, HIGH SPEED
NeoPixelBus<NeoGrbFeature, NeoEsp8266Uart800KbpsMethod> strip(N_PIXELS, PIXEL_PIN);


RgbColor red(COLOR_SATURATION, 0, 0);
RgbColor green(0, COLOR_SATURATION, 0);
RgbColor blue(0, 0, COLOR_SATURATION);
RgbColor white(COLOR_SATURATION);
RgbColor black(0);

HslColor hslRed(red);
HslColor hslGreen(green);
HslColor hslBlue(blue);
HslColor hslWhite(white);
HslColor hslBlack(black);

bool INLED = false;


void setup()
{
  // Init serial.
  Serial.begin(115200);
  while (!Serial); // wait for serial attach

  // Init outputs.
  pinMode(LED_BUILTIN, OUTPUT);     // Initialize the LED_BUILTIN pin as an output
  servo.attach(SERVO_PIN); // attach servo to WEMOS pin D3

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
  Serial.print("Local port: ");
  Serial.println(Udp.localPort());


  // Init LED strip.
  strip.Begin();
  strip.Show();

  for (int i=0; i< N_PIXELS; ++i){
    strip.SetPixelColor(i, red);
  }
  strip.Show();
  delay(500);

  for (int i=0; i< N_PIXELS; ++i){
    strip.SetPixelColor(i, green);
  }
  strip.Show();
  delay(500);

  for (int i=0; i< N_PIXELS; ++i){
    strip.SetPixelColor(i, blue);
  }
  strip.Show();
  delay(500);

  for (int i=0; i< N_PIXELS; ++i){
    strip.SetPixelColor(i, hslBlack);
  }
  strip.Show();
  delay(100);

  // Blink indicator led.
  digitalWrite(LED_BUILTIN, LOW);   // Turn the LED on (Note that HIGH is the voltage level
  delay(1000);
  digitalWrite(LED_BUILTIN, HIGH);   // Turn the LED off (Note that LOW is the voltage level
}

/////////////////////////////////////
void loop()
{
  receiveOsc();
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
      in.route("/xenopixels", onXenopixels);
      in.route("/xenoshutter", onXenoshutter);
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
void onXenopixels(OSCMessage &msg, int addrOffset) {

  int r, g, b;

  if( msg.isInt(0)) {
    r = msg.getInt(0);
    g = msg.getInt(1);
    b = msg.getInt(2);
  }

  Serial.println("osc_color: " + String(r) + " " + String(g) + " " + String(b));

  RgbColor oscColor(r, g, b);

  for (int i=0; i< N_PIXELS; ++i){
    strip.SetPixelColor(i, oscColor);
  }
  strip.Show();

  // delay(20);
}


/////////////////////////////////////
void onXenoshutter(OSCMessage &msg, int addrOffset) {

 // myservo.attach(SERVO_PIN, 500, 2400);

 // delay(50);

  if( msg.isInt(0)) {
    sangle = msg.getInt(0);
  }

  if (sangle == 0){ sangle = 12;}

  Serial.println("servo angle: " + String(sangle));

  if (sangle <=12) { sangle = 12; }

  servo.write(sangle); // set the servo position to the given angle

  delay(100);

 // myservo.detach();   // detaches the servo

}
