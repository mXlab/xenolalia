#pragma once
#include <PlaquetteLib.h>
#include <NeoPixelBus.h>

/** @brief This file handles basic interaction with the pixel ring
 */

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
     * @brief Apply a wave to the pixel ring
     * @param wave the wave to apply
     * @param colorA the first color of the wave
     * @param colorB the second color of the wave
     */
    void apply_wave(pq::SineOsc& wave, const RgbColor& colorA, const RgbColor& colorB, uint8_t nCycles = 1);

    /**
     * @brief scroll through all the colors at the passed interval
     * @param time pause between colors in millis
     */
    void test(const int time);
}