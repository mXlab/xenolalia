/*
  OLEDMonoReceiveMedia.ino

  Copyright (c) 2020, sofianaudry.com
  Copyright (c) 2016, olikraus@gmail.com
  All rights reserved.

  Redistribution and use in source and binary forms, with or without modification, 
  are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice, this list 
    of conditions and the following disclaimer.
    
  * Redistributions in binary form must reproduce the above copyright notice, this 
    list of conditions and the following disclaimer in the documentation and/or other 
    materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND 
  CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.  
*/

#include <Arduino.h>
#include <U8g2lib.h>

#include <PacketSerial.h>

#ifdef U8X8_HAVE_HW_SPI
#include <SPI.h>
#endif
#ifdef U8X8_HAVE_HW_I2C
#include <Wire.h>
#endif

#define BAUDRATE 1000000

U8G2_SSD1327_MIDAS_128X128_F_4W_SW_SPI u8g2(U8G2_R0, /* clock=*/ 33, /* data=*/ 15, /* cs=*/ 27, /* dc=*/ 12, /* reset=*/ 13);

#include <WiFi.h>
#include <WiFiUdp.h>
#include <OSCMessage.h>
#include <OSCBundle.h>
#include <OSCData.h>

#include "Config.h"

// A UDP instance to let us send and receive packets over UDP
WiFiUDP Udp;
//const IPAddress outIp(DESTINATION_IP_0, DESTINATION_IP_1, DESTINATION_IP_2, DESTINATION_IP_3);        // remote IP (not needed for receive)

OSCErrorCode error;

void connect(unsigned long timeout=10000) {
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print("Trying to connect");
    WiFi.disconnect(false, true);
    WiFi.begin(NETWORK_SSID, NETWORK_PASSWORD);
  
    unsigned long startTime = millis();
    while (WiFi.status() != WL_CONNECTED && (millis()-startTime) < timeout) {
      delay(500);
      Serial.print(".");
    }
    Serial.println("");
  }
}

void setup() {
  Serial.begin(BAUDRATE);

  // Connect to WiFi network
  Serial.println();
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(NETWORK_SSID);

  connect();

  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());

  Serial.println("Starting UDP");
  Udp.begin(LOCAL_PORT);
  Serial.print("Local port: ");
#ifdef ESP32
  Serial.println(LOCAL_PORT);
#else
  Serial.println(Udp.localPort());
#endif

  u8g2.begin();
}

void loop() {
  OSCMessage msg;
  int size = Udp.parsePacket();

  if (size > 0) {
    while (size--) {
      msg.fill(Udp.read());
    }
    if (!msg.hasError()) {
      msg.dispatch("/xeno/image", onImageReceived);
    } else {
      error = msg.getError();
      Serial.print("error: ");
      Serial.println(error);
    }
  }
}

void onImageReceived(OSCMessage &msg) {
  // Read header information.
  uint8_t imageWidth = msg.getInt(0);
  uint8_t imageHeight = msg.getInt(1);

  uint8_t imageX = (128 - imageWidth)/2;
  uint8_t imageY = (128 - imageHeight)/2;

  int imageSize = imageWidth * imageHeight;
  int bufferSize = imageSize / 8;

  uint8_t buffer[bufferSize];
  msg.getBlob(2, buffer, bufferSize);
  
  // Update image on screen.
  u8g2.clearBuffer();
  u8g2.setDrawColor(1);
  u8g2.setBitmapMode(true /* solid */);
  u8g2.drawXBMP(imageX, imageY, imageWidth, imageHeight, buffer);
  u8g2.sendBuffer();

  // Sends back response to confirm reception.
  Serial.println("Received image");
}
