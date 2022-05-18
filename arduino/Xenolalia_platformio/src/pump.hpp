#pragma once 
#include<string>    

class Pump{

    int mPin;
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