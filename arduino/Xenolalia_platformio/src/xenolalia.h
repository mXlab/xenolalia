#pragma once

#include <PlaquetteLib.h>

//Foraward declaration
class Pump;

namespace xenolalia{

   extern Pump out_pump;
   extern Pump in_pump;

   extern pq::SineOsc glowLfo;
   extern bool isGlowing;

   /** @brief initialize project hardware
    */
   void init();

   void update();

   /** @brief Start an experiment cycle. This function refresh the euglena in the petridish
    *         by pumping out the liquid in the tube, starting a complete shake cycle and
    *         pumping the liquid back in the petridish 
    */
   void cycle();

   /** @brief fill the petridish with liquid
    */
   void fill_petridish(float level=1.0f);

   /** @brief empty the petridish of its liquid
    */
   void empty_petridish();

   /** @brief test routine for the project's hardware
    */
   void test();

   /**
    * @brief drain the liquid out of the tube
    * 
    */
   void drain(bool on);

   /** @brief used to pump in the euglena in the tube
    */
   void fill(bool on);

   /** @brief perform a mix cycle of the euglena
    */
   void mix();

   /** @brief Set the color of the LED ring.
    */
   void setColor(int r, int g, int b);
   
   /** @brief Set the glowing state of the LED ring.
    */
   void glow(bool on);

   /**
    * @brief Get the petridish current level
    * @param nReadings number of readings of the sensor
    * @return int liquid level
    */
   int get_petridish_level(int nReadings=20);

   /**
    * @brief Check if the petridish is full
    */
   bool petridish_full(int nReadings=20);
   

}//namespace xenolalia