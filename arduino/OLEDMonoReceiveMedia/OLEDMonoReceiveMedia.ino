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

PacketSerial_<SLIP, SLIP::END, 4096> slipSerial;

U8G2_SSD1327_MIDAS_128X128_F_4W_SW_SPI u8g2(U8G2_R0, /* clock=*/ 33, /* data=*/ 15, /* cs=*/ 27, /* dc=*/ 12, /* reset=*/ 13);

void setup() {
  delay(500);
  // put your setup code here, to run once:
  slipSerial.begin(BAUDRATE);
  while (!Serial);
  slipSerial.setPacketHandler(onPacketReceived);

  u8g2.begin();
}

void loop(void) {
  slipSerial.update();
}

uint8_t OKAY = 0x0C;

void onPacketReceived(const uint8_t* buffer, size_t size)
{
  if (size > 0) {
    // Read header information.
    uint8_t imageWidth = *buffer++;
    uint8_t imageHeight = *buffer++;
    uint8_t imageX = (128 - imageWidth)/2;
    uint8_t imageY = (128 - imageHeight)/2;

    // Update image on screen.
    u8g2.clearBuffer();
    u8g2.setDrawColor(1);
    u8g2.setBitmapMode(true /* solid */);
    u8g2.drawXBMP(imageX, imageY, imageWidth, imageHeight, buffer);
    u8g2.sendBuffer();

    // Sends back response to confirm reception.
    slipSerial.send(&OKAY, 1);
  }
}
