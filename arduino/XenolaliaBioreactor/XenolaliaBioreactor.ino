/* XENOLALIA project - TeZ + Sofian 2017 */

 #include <Timer.h>

 
int ardled = 13;       // the PWM pin the LED is attached to
int led = 3;           // the PWM pin the LED is attached to
int brightness = 00;   // how bright the LED is
int fadeAmount = 5;    // how many points to fade the LED by

// transistor control pins
int lite = 3; 
int fan = 11;
int pump = 10;
int xtra = 9;

// Timers declarations
Timer liteTimer;
Timer pumpTimer;
Timer fanTimer;

// timer vars
int8_t id_Pump_off, id_Pump_on;
unsigned long pump_on_time;
unsigned long pump_off_time;

int8_t id_Lite_off, id_Lite_on;
unsigned long lite_on_time;
unsigned long lite_off_time;

int8_t id_Fan_off, id_Fan_on;
unsigned long fan_on_time;
unsigned long fan_off_time;


// the setup routine runs once when you press reset:
void setup() {

// Serial.begin(9600); 
//   while (!Serial) {
//    ; // wait for serial port to connect. Needed for native USB
//  }
  
  // declare pins to be an output:
  pinMode(ardled, OUTPUT);
  pinMode(led, OUTPUT);
  pinMode(lite, OUTPUT);
  pinMode(fan, OUTPUT);
  pinMode(pump, OUTPUT);
  pinMode(xtra, OUTPUT);

  pump_on_time = 10UL * 1000UL;// time for pump ON = 5 seconds
  pump_off_time = 20UL * 1000UL;// time for pump = 25 seconds

  lite_on_time = 15UL * 60UL * 60UL * 1000UL;// time for light ON  = 15 hours
  lite_off_time = 9UL * 60UL * 60UL * 1000UL;// time for light OFF = 9 hours
 
  fan_on_time = 60UL * 1000UL;// time for fan ON  = 1 minute
  fan_off_time = 59UL * 60UL * 1000UL;// time for fan OFF = 59 minutes


 analogWrite(lite, 125);
 analogWrite(pump, 75);
 analogWrite(fan, 250);

 delay (4000);
 analogWrite(fan, 0);



  // START LITE TIMER
   id_Lite_on  = liteTimer.after(lite_on_time, liteOn);

 // START FAN TIMER
  id_Fan_on  = fanTimer.after(fan_on_time, fanOn);
  
  // START PUMP TIMER
  id_Pump_on  = pumpTimer.after(pump_on_time, pumpaOn);
  
  
  
}

///////////////////////////////////////////
void loop() {

 pumpTimer.update();
 liteTimer.update();
 fanTimer.update();


  delay(20);
}


//////////////////////////////////////////
void pumpaOn () {   
   analogWrite(pump, 0);
   id_Pump_off  = pumpTimer.after(pump_off_time, pumpaOff);  
   pumpTimer.stop(id_Pump_on);
}

//////////////////////////////////////////
void pumpaOff () {
   analogWrite(pump, 75);
   id_Pump_on  = pumpTimer.after(pump_on_time, pumpaOn); 
   pumpTimer.stop(id_Pump_off);
}


//////////////////////////////////////////
void liteOn () {  
   analogWrite(lite, 0);
   id_Lite_off  = liteTimer.after(lite_off_time, liteOff);  
   liteTimer.stop(id_Lite_on);
}

//////////////////////////////////////////
void liteOff () {
   analogWrite(lite, 125);
   id_Lite_on  = liteTimer.after(lite_on_time, liteOn); 
   liteTimer.stop(id_Lite_off);
}



//////////////////////////////////////////
void fanOn () {
   // fanTimer.stop(id_Fan_on);
   analogWrite(fan, 0);
   id_Fan_off  = fanTimer.every(fan_off_time, fanOff); 
   fanTimer.stop(id_Fan_on);
  //Serial.println("Fan OFF");
}

//////////////////////////////////////////
void fanOff () {
   // fanTimer.stop(id_Fan_off);
   analogWrite(fan, 250);
   id_Fan_on  = fanTimer.every(fan_on_time, fanOn); 
   fanTimer.stop(id_Fan_off);
  //Serial.println("Fan ON");
}


