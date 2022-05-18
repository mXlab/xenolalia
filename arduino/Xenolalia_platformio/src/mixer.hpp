#pragma once

class Servo;

namespace euglena_mixer{

    extern Servo servo;  // Create object for servo motor

    /** @brief initialization routine
     */
    void init();


    /** @brief
     *  This function performs a test cycle on the servo motor. 
     *  It will go from 0 to its max rotation, stop, come back to 0 and stop again. 
     */
    void test();

    /**
     * @brief move the servo
     * @param start start position of the movement
     * @param stop  stop position of the movement
     * @param clockwise false for counter clockwise
     */
    void rotate(const int start ,const int stop ,const bool clockwise );


    /** @brief  perform a mix cycle of the euglena
     */
    void mix();




}//namespace euglena_mixer