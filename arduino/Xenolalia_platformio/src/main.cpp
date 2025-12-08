///////////////////////////////////////////////////
// XENOLALIA ESP32 OSC controls - TeZ March 2021 //
///////////////////////////////////////////////////
/*
    This code controls the hardware contained in the Xenolalia box
      - Pump 1 & 2 
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
//--------------------------------------------


#include <Arduino.h>
#include "xenolalia.h"
#include "osc.hpp"
#include "ota.hpp"

#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
void setup() 
{
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0); //disable brownout detector

  Serial.begin(9600);
  delay(2000);
  xenolalia::init();
  osc::connect_to_wifi(osc::ssid, osc::pass);
  osc::init_udp(); 
  ota::init(osc::local_IP[3]);
  Serial.println("Xenolalia");

  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 1); //reenable brownout detector
}

void loop()
{
  ota::update();
  osc::wifi_check_connection();
  osc::update();
  xenolalia::update();
}
