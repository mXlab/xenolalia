#include "xenolalia.h"
#include "pins.h"



#include "mixer.hpp"
#include "pump.hpp"
#include "pixel_ring.hpp"
#include "liquid_sensor.hpp"
#include "osc.hpp"


namespace xenolalia{
    

    Pump in_pump(pins::pump1);
    Pump out_pump(pins::pump2);
    Liquid_level_sensor liquid_sensor(pins::liquid_sensor);
    const int threshold{500};

    void init(){
    
        in_pump.init();
        out_pump.init();
        pixel_ring::init();
        liquid_sensor.init();
        euglena_mixer::init();  
    }

    void cycle(){

        osc::send("/debug" , "Emptying petridish");
        empty_petridish();
        delay(2000);
        
        osc::send("/debug", "Mixing the euglena");
        for(int i{0}; i<2; i++)
        {
            pixel_ring::set_color(pixel_ring::blue);
            euglena_mixer::mix();
        }
        delay(2000);

        osc::send("/debug", "Filling the petridish with euglena");
        
        // First: fill full.
        fill_petridish();
        delay(5000); // wait for the "wash" effect

        // Empty again.
        empty_petridish();
        delay(500);

        // Second: fill partially.
        fill_petridish(0.67);
        delay(500);
   }

    void fill_petridish(float level){
    #define MAX_PUMP_COUNT 24
    int dishlevel = 1;
    int numPump = (int) (MAX_PUMP_COUNT*level);
    numPump = constrain(numPump, 0, MAX_PUMP_COUNT);
    bool petriFull{false};
    char buff[64];
   
    while(petriFull == false)
    {
      
     
      for( int i{0} ; i < numPump ; i++)
      {
      
        dishlevel = get_petridish_level();
        sprintf(buff, "dishlevel : %d | liquid Treshold : %d " ,dishlevel , threshold);
        osc::send("/debug", buff);

        if(dishlevel >= threshold)
        {
          petriFull = true;
          break;
        }

        out_pump.start(250);
      }

      petriFull = true;
      osc::send("/debug", "Exceded max pump count" );  
    }

    delay(500);
    osc::send("/debug", "Petridish is full" );
    pixel_ring::set_color(pixel_ring::black);

   }
  
    void empty_petridish(){
       pixel_ring::set_color(pixel_ring::yellow);
       in_pump.start(15000);
       pixel_ring::set_color(pixel_ring::black);
   }
  
    void test(){
    const int pause{2000};
    osc::send("/debug" , "Testing pixel ring .\n Cycling through colors.");
    pixel_ring::test(1000);
    delay(pause);

    osc::send("/debug" , "Testing servo moter .\n Moving left and right.");
    euglena_mixer::test();
    delay(pause);


    osc::send("/debug" , "Testing output pump .\n Pumping 1 shot in petridish.");
    out_pump.start(5000);
    delay(pause);

    osc::send("/debug" , "Testing input pump .\n Emptying out petridish.");
    in_pump.start(5000);
    delay(pause);

  }

    void drain(bool on)
  {
    if(on)
    {
      in_pump.start();
    }else
    {
      in_pump.stop();
    }
  }

    void fill(bool on)
  {
    if(on)
    {
      out_pump.start();
    }else
    {
      out_pump.stop();
    }
    
    
  }
  
    int get_petridish_level()
  {
    int liquidLevel{0};
    int myLevel{0};

    pixel_ring::set_color(pixel_ring::black);
    for(int i=1; i<=20; ++i)
    {
      liquidLevel=liquid_sensor.get_level();
      myLevel += liquidLevel;
      delay(10);
    }
    
    liquidLevel = int(myLevel/20);
    
      
      if(liquidLevel < threshold)
      { 
         pixel_ring::set_color(pixel_ring::green);
        //  delay(100);
        //  pixel_ring::set_color(pixel_ring::black);
      }
      else
      {
         pixel_ring::set_color(pixel_ring::red);
         delay(100);
      }
      return liquidLevel;
   }

}//namespace xenolalia