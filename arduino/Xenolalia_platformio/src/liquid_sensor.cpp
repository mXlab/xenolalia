#include "liquid_sensor.hpp"
#include <Arduino.h>


Liquid_level_sensor::Liquid_level_sensor(const int& pin):mPin{pin}
{}

void Liquid_level_sensor::init(){
    pinMode(mPin, INPUT);
}

int Liquid_level_sensor::get_level(){
    level = analogRead(mPin);
    return level;
}