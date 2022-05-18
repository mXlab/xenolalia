#pragma once

class Liquid_level_sensor{

    int mPin;
    int level{0};

    public:

    Liquid_level_sensor(const int& pin);

    /** @brief initialization routine 
     */
    void init();

    /**
     * @brief return current liquid level 
     * @return level 
     */
    int get_level();
};