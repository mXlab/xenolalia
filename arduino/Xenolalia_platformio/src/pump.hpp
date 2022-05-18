#pragma once 
#include<string>    

/**@brief Basic class to interface with pump
 */

class Pump{

    int _pin;
    bool running{false};
    
    public :
    Pump(const int& pin);

    /** @brief Start the pump indefinitly
     */
    void start();

    /** @brief Start the pump for an X amount of time
     *  @param timeout amount of time in millis
     */
    void start(int timeout);

    /** @brief Stop the pump
     */
    void stop();

    /** @brief Pump initialization routine
     */
    void init();
};