#include "mixer.hpp"
#include <ESP32Servo.h>
#include <pins.h>
#include "pixel_ring.hpp"

namespace euglena_mixer{

    Servo servo;  // Create object for servo motor

    int pos {0};    // variable to store the servo position
    int maxrotation {95}; //max rotation of the servo in degree
    int zpeed {10}; // pause in MS between each step took by the servo
    int restime {100}; //rest time between certain steps in the cycle. in MS
    int shaketimes {3}; //number of time the tube is shaked in a complete cycle

    void init(){
        servo.attach(pins::servo);
    }

    void test(){

        rotate(0,maxrotation, true);
        delay(restime);
        rotate(maxrotation,0,false);
        delay(restime);

    }

    void rotate(const int start ,const int stop ,const bool clockwise ){
        
        if(clockwise){

            for(int posDegrees{start}; posDegrees <= stop; posDegrees++) 
            {
                servo.write(posDegrees);
                delay(zpeed);
            }

        }else{
            
            for(int posDegrees{start}; posDegrees >= stop; posDegrees--) 
            {
                servo.write(posDegrees);
                delay(zpeed);
            }
        }
    
    }
    

    void mix()
    {
        pixel_ring::set_color(pixel_ring::blue);
  
        rotate(0,maxrotation,true);
        delay(restime);

        // MID SHAKE
        for(int i=1; i<=7; i++)
        {  
            pixel_ring::set_color(pixel_ring::blue);
            rotate(maxrotation,50,false);
            pixel_ring::set_color(pixel_ring::white);
            rotate(50,maxrotation,true);
        }
  
        pixel_ring::set_color(pixel_ring::blue); 
        rotate(maxrotation,0,false);
        delay(restime);
        pixel_ring::set_color(pixel_ring::black);

    }


}//namespace euglena_mixer