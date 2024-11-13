#pragma once

//Foraward declaration
class Pump;

namespace xenolalia{

   extern  Pump out_pump;
   extern  Pump in_pump;

   /** @brief initialize project hardware
    */
   void init();

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

   /**
    * @brief Get the petridish current level
    * @return int liquid level
    */
   int get_petridish_level();
   

}//namespace xenolalia