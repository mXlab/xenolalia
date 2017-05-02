/* XENOLALIA project - TeZ + Sofian 2017 */

#include <Chrono.h>
#include <DS3231_Simple.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Adafruit_NeoPixel.h>
#ifdef __AVR__
  #include <avr/power.h>
#endif

// Real-time clock.
DS3231_Simple rtc;

// Hours of day where lights come on/off.
#define LIGHT_HOUR_ON  10
#define LIGHT_HOUR_OFF 19

// Euglena optimum growth rate 25-30 C (source: http://www.metamicrobe.com/euglena/)
// So we keep it around 27.5+-1 C
#define TEMPERATURE_MIN   26.5f
#define TEMPERATURE_MAX   28.5f

// Timer constants.
#define PUMP_ON_TIME     5000UL //  5 seconds (every 2 minutes)
#define STIRRER_ON_TIME 60000UL // 60 seconds (every hour)

// On/off PWM values (adjust according to needs).
#define LIGHT_VALUE_ON  125
#define LIGHT_VALUE_OFF   0

#define STIRRER_VALUE_ON  250
#define STIRRER_VALUE_OFF   0

#define PUMP_VALUE_ON   75
#define PUMP_VALUE_OFF   0

#define HEATER_VALUE_ON  255
#define HEATER_VALUE_OFF   0

// Transistor control pins.
#define LIGHT_OUT          6 // neopixel
#define STIRRER_AOUT      10
#define PUMP_AOUT          9
#define HEATER_AOUT       11
#define INDICATOR_LED_OUT 13 // indicator LED is used to show that lights are switched on

// Light-related.
#define LIGHT_N_PIXELS    24 // n. pixels in the neopixel
const uint32_t LIGHT_COLOR = Adafruit_NeoPixel::Color(255, 255, 255);

// Temperature control.
#define TEMPERATURE_ONE_WIRE_BUS 5


// When we setup the NeoPixel library, we tell it how many pixels, and which pin to use to send signals.
// Note that for older NeoPixel strips you might need to change the third parameter--see the strandtest
// example for more information on possible values.
Adafruit_NeoPixel pixels = Adafruit_NeoPixel(LIGHT_N_PIXELS, LIGHT_OUT, NEO_GRB + NEO_KHZ800);

// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire temperatureOneWire(TEMPERATURE_ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature temperatureSensor(&temperatureOneWire);
// Timer declarations.
Chrono pumpTimer;
Chrono stirrerTimer;

void setup() {

   Serial.begin(9600);
     while (!Serial) {
      ; // wait for serial port to connect. Needed for native USB
    }

  // Set pins.
  pinMode(STIRRER_AOUT, OUTPUT); digitalWrite(STIRRER_AOUT, LOW);
  pinMode(PUMP_AOUT,    OUTPUT); digitalWrite(PUMP_AOUT,    LOW);
  pinMode(HEATER_AOUT,  OUTPUT); digitalWrite(HEATER_AOUT,  LOW);
  // Init neopixel.
  pixels.begin();

  // Start real-time clock.
  rtc.begin();
  
  // We will set 2 alarms, the first alarm will fire at the 30th second of every minute
  //  and the second alarm will fire every minute (at the 0th second)
  
  // First we will disable any existing alarms.
  rtc.disableAlarms();

  // Run initialization test.
  runTest();
  
  // Alarm 2 runs every minute.
  rtc.setAlarm(DS3231_Simple::ALARM_EVERY_MINUTE);

  setLight(true);
  startPump();
  startStirrer();
  
  delay (4000);
  updateLight(rtc.read());
  updateHeater(temperature());
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


    DateTime timestamp = rtc.read();

    // Every 2 minutes, start the pump.
    if (timestamp.Minute % 2 == 0) {
      // Start pump.
      startPump();
    }

    // Every hour (ie. first minute of the hour)
    if (timestamp.Minute == 0) {
      // Start magnetic stirrer.
      startStirrer();
    }

    // Update light values according to current time.
    updateLight(timestamp);

    // Update heater.
    updateHeater(temperature());
  }

  delay(200);
}

// Adjust lighting depending on time of day.
void updateLight(const DateTime& timestamp) {
  uint8_t hour = timestamp.Hour;
  setLight(LIGHT_HOUR_ON <= hour && hour < LIGHT_HOUR_OFF);
}

void updateHeater(float temp) {
  Serial.print("Temperature is: "); Serial.println(temp);
  if (temp < TEMPERATURE_MIN)
    setHeater(true);
  else if (temp > TEMPERATURE_MAX)
    setHeater(false);
}

// Control functions //////////////////////////////////////////////
void setLight(bool isOn) {
  rtc.printTimeTo_HMS(Serial);
  Serial.print(" :: Set light to "); Serial.println(isOn ? "ON" : "OFF");

  for(int i=0;i<LIGHT_N_PIXELS;i++) {
    // pixels.Color takes RGB values, from 0,0,0 up to 255,255,255
    pixels.setPixelColor(i, LIGHT_COLOR);
    pixels.setBrightness(isOn ? LIGHT_VALUE_ON : LIGHT_VALUE_OFF);
   // 610 nm wavelength = 255,155,0 RGB

    pixels.show(); // This sends the updated pixel color to the hardware.
  }
  
  digitalWrite(INDICATOR_LED_OUT, isOn ? HIGH : LOW);
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

void setHeater(bool isOn) {
  rtc.printTimeTo_HMS(Serial);
  Serial.print(" :: Set heater to "); Serial.println(isOn ? "ON" : "OFF");
  analogWrite(HEATER_AOUT, isOn ? HEATER_VALUE_ON : HEATER_VALUE_OFF);
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

float temperature() {
  temperatureSensor.requestTemperatures(); // Send the command to get temperatures
  return temperatureSensor.getTempCByIndex(0);
}

void waitForInputSerial() {
  while (!Serial.available()) delay(10);
  flushInputSerial();
}

void flushInputSerial() {
  while (Serial.available())
    Serial.read();
}

void runTest() {
  // Check if user wants to run tests.
  Chrono testWait;
  Serial.println("Send any key to start tests (timeout: 10s).");
  while (!Serial.available())
    if (testWait.hasPassed(10000UL))
      return;
  flushInputSerial();

  // Start tests.
  Serial.println("======= XENOLALIA TEST BEGIN =======");
  Serial.println("After every test send a key to stop and go to next test");
  
  // Test inputs.
  Serial.println("Test time");
  rtc.printTimeTo_HMS(Serial);  

  Serial.println("Test temperature");
  Serial.println(temperature());

  // Test outputs.
  Serial.println("Check that everything is at 0V");
  waitForInputSerial();

  Serial.println("Test pump");
  setPump(true);
  waitForInputSerial();
  setPump(false);
  
  Serial.println("Test stirrer");
  setStirrer(true);
  waitForInputSerial();
  setStirrer(false);

  Serial.println("Test light");
  setLight(true);
  waitForInputSerial();
  setLight(false);

  Serial.println("Test heater");
  setHeater(true);
  waitForInputSerial();
  setLight(false);

  Serial.println("======== XENOLALIA TEST END ========");
}

