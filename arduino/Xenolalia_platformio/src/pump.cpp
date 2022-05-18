#include "pump.hpp"
#include <Arduino.h>

Pump::Pump(const int& pin): mPin{pin}
{}

void Pump::init(){
    pinMode(mPin,OUTPUT);
    stop();
    
}


void Pump::start(){
    digitalWrite(mPin,HIGH);
    running = true;
}

void Pump::start(int timeout){
    start();
    delay(timeout);
    stop();
}


void Pump::stop(){
    digitalWrite(mPin,LOW);
    running = false;
}




