/* XENOLALIA project - TeZ + Sofian 2017 */

#include <Chrono.h>
#include <DS3231_Simple.h>

// Real-time clock.
DS3231_Simple rtc;

#define LIGHT_HOUR_ON  10
#define LIGHT_HOUR_OFF 19

#define LIGHT_VALUE_ON  125
#define LIGHT_VALUE_OFF   0

#define STIRRER_VALUE_ON  250
#define STIRRER_VALUE_OFF   0

#define PUMP_VALUE_ON   75
#define PUMP_VALUE_OFF   0

// transistor control pins
#define LIGHT_AOUT    3
#define STIRRER_AOUT 11
#define PUMP_AOUT    10
#define XTRA_AOUT     9

// Timer declarations.
Chrono pumpTimer;
Chrono stirrerTimer;

// timer vars
#define PUMP_ON_TIME    20000UL // 20 seconds (every minute)
#define STIRRER_ON_TIME 60000UL // 60 seconds (every hour)

// the setup routine runs once when you press reset:
void setup() {

   Serial.begin(9600);
     while (!Serial) {
      ; // wait for serial port to connect. Needed for native USB
    }

  // Set pins.
  pinMode(LIGHT_AOUT,   OUTPUT);
  pinMode(STIRRER_AOUT, OUTPUT);
  pinMode(PUMP_AOUT,    OUTPUT);

  // Start real-time clock.
  rtc.begin();
  
  // We will set 2 alarms, the first alarm will fire at the 30th second of every minute
  //  and the second alarm will fire every minute (at the 0th second)
  
  // First we will disable any existing alarms.
  rtc.disableAlarms();
  
  // Alarm 2 runs every minute.
  rtc.setAlarm(DS3231_Simple::ALARM_EVERY_MINUTE);

  setLight(true);
  startPump();
  startStirrer();
  
  delay (4000);
  updateLight(rtc.read());
}

///////////////////////////////////////////
void loop() {

  // Check for stop conditions of pump and stirrer.
  if (pumpTimer.isRunning() && pumpTimer.hasPassed(PUMP_ON_TIME))          stopPump();
  if (stirrerTimer.isRunning() && stirrerTimer.hasPassed(STIRRER_ON_TIME)) stopStirrer();

  // To check the alarms we just ask the clock
  uint8_t alarmsFired = rtc.checkAlarms();

  // Alarm 2 fired (minute alarm).
  if (alarmsFired & 2) {

    // Start pump.
    startPump();

    DateTime timestamp = rtc.read();

    // Every hour (ie. first minute of the hour)
    if (timestamp.Minute == 0) {
      // Start magnetic stirrer.
      startStirrer();
    }

    // Update light values according to current time.
    updateLight(timestamp);
  }

  delay(20);
}

// Adjust lighting depending on time of day.
void updateLight(const DateTime& timestamp) {
  uint8_t hour = timestamp.Hour;
  setLight(LIGHT_HOUR_ON <= hour && hour < LIGHT_HOUR_OFF);
}

// Control functions //////////////////////////////////////////////
void setLight(bool isOn) {
  rtc.printTimeTo_HMS(Serial);
  Serial.print(" :: Set light to "); Serial.println(isOn ? "ON" : "OFF");
  analogWrite(LIGHT_AOUT, isOn ? LIGHT_VALUE_ON : LIGHT_VALUE_OFF);
}

void setStirrer(bool isOn) {
  rtc.printTimeTo_HMS(Serial);
  Serial.print(" :: Set stirrer to "); Serial.println(isOn ? "ON" : "OFF");
  analogWrite(STIRRER_AOUT, isOn ? STIRRER_VALUE_ON : STIRRER_VALUE_OFF);
}

void setPump(bool isOn) {
  rtc.printTimeTo_HMS(Serial);
  Serial.print(" :: Set pump to "); Serial.println(isOn ? "ON" : "OFF");
  analogWrite(PUMP_AOUT, isOn ? PUMP_VALUE_ON : PUMP_VALUE_OFF);
}

void startStirrer() {
  setStirrer(true);
  stirrerTimer.start();
}

void stopStirrer() {
  setStirrer(false);
  stirrerTimer.stop();
}

void startPump() {
  setPump(true);
  pumpTimer.start();
}

void stopPump() {
  setPump(false);
  pumpTimer.stop();
}


