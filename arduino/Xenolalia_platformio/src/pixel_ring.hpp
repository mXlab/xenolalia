#pragma once
#include <NeoPixelBus.h>


namespace pixel_ring{

    extern RgbColor red;
    extern RgbColor green;
    extern RgbColor blue;
    extern RgbColor yellow;
    extern RgbColor white;
    extern RgbColor black;
    extern NeoPixelBus<NeoGrbFeature, Neo800KbpsMethod> ring;

    /** @brief initialization routine
     */
    void init();

    /**
     * @brief Set the pixel ring the passed color
     * @param color 
     */
    void set_color(const RgbColor& color);

    /**
     * @brief scroll through all the colors at the passed interval
     * @param time pause between colors in millis
     */
    void test(const int time);
}