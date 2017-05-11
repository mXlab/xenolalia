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
// Based on recommendations from Carolina: 16 hours light, 8 hours dark
#define LIGHT_HOUR_ON  7
#define LIGHT_HOUR_OFF 23

// Euglena optimum growth rate 25-30 C (source: http://www.metamicrobe.com/euglena/)
// So we keep it around 27.5+-1 C
#define TEMPERATURE_MIN   26.5f
#define TEMPERATURE_MAX   28.5f

#define TEMPERATURE_TARGET_MIN 25.0f
#define TEMPERATURE_TARGET_MAX 30.0f

// If we reach that point, it either means that the euglenas are dead or that the temperature sensor is disconnected, 
// returning DEVICE_DISCONNECTED = -127 (in both cases we must stop heating).
#define TEMPERATURE_MIN_ERROR -10.0f

// Timer constants.
#define PUMP_ON_TIME     5000UL //  5 seconds (every 2 minutes)
#define STIRRER_ON_TIME 60000UL // 60 seconds (every hour)

// On/off PWM values (adjust according to needs).
#define LIGHT_VALUE_ON  255
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

bool heaterIsOn = false;

void setup() {

  Serial.begin(9600);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB
  }

  // Set pins.
  pinMode(STIRRER_AOUT,       OUTPUT); digitalWrite(STIRRER_AOUT, LOW);
  pinMode(PUMP_AOUT,          OUTPUT); digitalWrite(PUMP_AOUT,    LOW);
  pinMode(HEATER_AOUT,        OUTPUT); digitalWrite(HEATER_AOUT,  LOW);
  pinMode(INDICATOR_LED_OUT,  OUTPUT); digitalWrite(INDICATOR_LED_OUT,  LOW);

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

  // Start stuff (for testing purposes).
  setLight(true);
  startPump();
  startStirrer();
  
  delay (1000);
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

    // Read time.
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
  bool heaterPrevIsOn = heaterIsOn;
  if (temp < TEMPERATURE_MIN_ERROR) {
    setHeater(false);
    Serial.println("Something is wrong. Please check connection of temperature sensor.");
  }
  else if (temp < TEMPERATURE_MIN)
    setHeater(true);
  else if (temp > TEMPERATURE_MAX)
    setHeater(false);

  // If heater was toggled OR if temperature becomes outside of target range: save to log.
  if ((heaterPrevIsOn != heaterIsOn) || 
      (temp < TEMPERATURE_TARGET_MIN || temp > TEMPERATURE_TARGET_MAX)) {
    int value = (int) (temp*10);
    if (heaterIsOn)
      value += 1000; 
    rtc.writeLog( value );
  }
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
  heaterIsOn = isOn; // save value
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
  Serial.println("Test date");
  rtc.printDateTo_YMD(Serial);
  Serial.println();
  Serial.println("Test time");
  rtc.printTimeTo_HMS(Serial);
  Serial.println();

  Serial.println("Change date/time? (Y/N)");
  while (!Serial.available()) delay(10);
  if (Serial.peek() == 'Y' || Serial.peek() == 'y') {
    flushInputSerial();
    Serial.println("Input new date time in format \"YY-MM-DDTHH:mm:ss\" eg. \"17-01-31T18:35:01\"");
    while (!Serial.available()) delay(10);
    DateTime timestamp;
    timestamp.Year   = Serial.readStringUntil('-').toInt();
    timestamp.Month  = Serial.readStringUntil('-').toInt();
    timestamp.Day    = Serial.readStringUntil('T').toInt();
    timestamp.Hour   = Serial.readStringUntil(':').toInt();
    timestamp.Minute = Serial.readStringUntil(':').toInt();
    timestamp.Second = Serial.readString().toInt();
    Serial.println("New date: ");
    Serial.print(timestamp.Year);   Serial.print("-");
    Serial.print(timestamp.Month);  Serial.print("-");
    Serial.print(timestamp.Day);    Serial.print("T");
    Serial.print(timestamp.Hour);   Serial.print(":");
    Serial.print(timestamp.Minute); Serial.print(":");
    Serial.print(timestamp.Second); Serial.println();
    Serial.println("Save new date/time? (Y/N)");
    while (!Serial.available()) delay(10);
    if (Serial.peek() == 'Y' || Serial.peek() == 'y') {
      rtc.write(timestamp);
      Serial.println("New date/time saved.");
      rtc.printDateTo_YMD(Serial);
      rtc.printTimeTo_HMS(Serial);
    }
    else
      Serial.println("Date/time change aborted.");
  }
  flushInputSerial();

  // Check/reset log.
  Serial.println("Dump log");
  dumpLog();
  Serial.println("Clear log? (Y/N)");
  while (!Serial.available()) delay(10);
  if (Serial.peek() == 'Y' || Serial.peek() == 'y') {
    flushInputSerial();
    rtc.formatEEPROM();
    Serial.println("Log cleared");
  }

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

void dumpLog()
{
  unsigned int loggedData;
  DateTime     loggedTime;
  
  // Note that reading a log entry also deletes the log entry
  // so you only get one-shot at reading it, if you want to do
  // something with it, do it before you discard it!
  unsigned int x = 0;
  while(rtc.readLog(loggedTime,loggedData))
  {
    if(x == 0)
    {
      Serial.println();
      Serial.println(F("Date,Temp (C)"));
    }
    
    x++;
    rtc.printTo(Serial,loggedTime);
    Serial.print(',');
    Serial.println(loggedData/10.0f);
  }
  Serial.println();
  Serial.print(F("# Of Log Entries Found: "));
  Serial.println(x);
  Serial.println();
}

