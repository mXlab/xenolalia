#include "xenolalia.h"
#include "pins.h"



#include "mixer.hpp"
#include "pump.hpp"
#include "pixel_ring.hpp"
#include "liquid_sensor.hpp"
#include "osc.hpp"

namespace xenolalia{

//    constexpr float fill_level{0.67}; // without pump insert
    constexpr float fill_level{0.50}; // with pump insert

    Pump in_pump(pins::pump1); // drain pump
    Pump out_pump(pins::pump2); // fill pump
    Liquid_level_sensor liquid_sensor(pins::liquid_sensor);
    constexpr int threshold{500};

    RingStyle ringStyle{RingStyle::DARK};

    pq::SineOsc glowLfo(20.0f);
    pq::SineOsc glowLfoShift(10.0f);
    RgbColor glowColorA(255, 0, 255);
    RgbColor glowColorB(255, 255, 255);
    constexpr int nGlowCycles{3};

    pq::SineOsc idleLfo(25.0f);
    RgbColor idleColorA(0, 0, 16);
    RgbColor idleColorB(0, 0, 0);
    constexpr int nIdleCycles{3};

    void init(){
        in_pump.init();
        out_pump.init();
        pixel_ring::init();
        liquid_sensor.init();
        euglena_mixer::init();
        pq::Plaquette.begin();
    }

    void update() {
      pq::Plaquette.step();

      // Prevent overflowing.
      if (out_pump.is_running() && petridish_full())
        out_pump.stop();

      // Animated ring styles: update color each loop.
      switch (ringStyle) {
        case RingStyle::GLOW:
          pixel_ring::apply_wave(glowLfoShift, 
                                 RgbColor::LinearBlend(glowColorA, glowColorB, glowLfo.mapTo(0,  0.7)), 
                                 RgbColor::LinearBlend(glowColorA, glowColorB, glowLfo.mapTo(0.1,  1)), 
                                 nGlowCycles);
          break;
        case RingStyle::IDLE:
          pixel_ring::apply_wave(idleLfo, idleColorA, idleColorB, nIdleCycles);
          break;
        default: break;  // DARK, GROW, and CUSTOM are set once, not animated
      }
    }

    void cycle(){
        RingStyle savedStyle = ringStyle;

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
        delay(10000); // wait for the "wash" effect

        // Empty again.
        empty_petridish();
        delay(500);

        // Second: fill partially.
        fill_petridish(fill_level);
        delay(500);

        // Restore the ring style that was active before the refresh cycle.
        setRingStyle(savedStyle);
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
  
    void mix() {
      euglena_mixer::mix();
    }

    void setColor(int r, int g, int b) {
      ringStyle = RingStyle::CUSTOM;
      RgbColor color(r, g, b);
      pixel_ring::set_color(color);
    }

    void setRingStyle(RingStyle style) {
      ringStyle = style;
      switch (style) {
        case RingStyle::DARK:       pixel_ring::set_color(pixel_ring::black); break;
        case RingStyle::GROW:       pixel_ring::set_color(pixel_ring::white); break;
        default: break;  // GLOW, IDLE, and CUSTOM are not reset here
      }
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
      if (petridish_full())
      {
        out_pump.stop();
      }
      else if(on)
      {
        out_pump.start();
      }
      else
      {
        out_pump.stop();
      }
    }
  
    int get_petridish_level(int nReadings)
    {
      int liquidLevel{0};

//      pixel_ring::set_color(pixel_ring::black);
      liquidLevel = liquid_sensor.get_level(nReadings);

      char buff[64];
      sprintf(buff, "dishlevel : %d | liquid Treshold : %d " ,liquidLevel , threshold);
      osc::send("/debug", buff);

      if(liquidLevel >= threshold)
      { 
        pixel_ring::set_color(pixel_ring::red);
      }
      else
      {
        pixel_ring::set_color(pixel_ring::green);
      }

      return liquidLevel;
    }

    bool petridish_full(int nReadings) {
      return get_petridish_level(nReadings) >= threshold;
    }

}//namespace xenolalia