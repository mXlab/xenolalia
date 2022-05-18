#include "pump.hpp"
#include <Arduino.h>

Pump::Pump(const int& pin): _pin{pin}
{}

void Pump::init(){
    pinMode(_pin,OUTPUT);
    stop();
    
}


void Pump::start(){
    digitalWrite(_pin,HIGH);
    running = true;
}

void Pump::start(int timeout){
    start();
    delay(timeout);
    stop();
}


void Pump::stop(){
    digitalWrite(_pin,LOW);
    running = false;
}




