#include "liquid_sensor.hpp"
#include <Arduino.h>


Liquid_level_sensor::Liquid_level_sensor(const int& pin):_pin{pin}
{}

void Liquid_level_sensor::init(){
    pinMode(_pin, INPUT);
}

int Liquid_level_sensor::get_level(int nReadings){
    long level = 0;
    for (int i = 0; i < nReadings; i++)
    {
        level += analogRead(_pin);
    }
    
    level /= nReadings;
    return (int)level;
}