#include "pixel_ring.hpp"
#include "pins.h"

/** @brief This file handles basic interaction with the pixel ring
 */

namespace pixel_ring{

    const int color_saturation{250};
    RgbColor red(color_saturation, 0, 0);
    RgbColor green(0, color_saturation, 0);
    RgbColor blue(0, 0, color_saturation);
    RgbColor yellow(color_saturation,color_saturation, 0);
    RgbColor white(color_saturation);
    RgbColor black(0);

    const int PixelCount{24};  //number of pixel on the ring

    NeoPixelBus<NeoGrbFeature, Neo800KbpsMethod> ring(PixelCount, pins::pixel);


    void init(){
        ring.Begin();
        ring.Show();
    }

    void set_color(const RgbColor& color){
        ring.ClearTo(color);
        ring.Show();
    }

    void apply_wave(pq::SineOsc& wave, const RgbColor& colorA, const RgbColor& colorB, uint8_t nCycles) {
        for (int i = 0; i < PixelCount; i++) {
            float t =  wave.shiftBy(pq::mapFloat(i, 0, PixelCount-1, 0, nCycles));
            ring.SetPixelColor(i, RgbColor::LinearBlend(colorA, colorB, t));
        }
        ring.Show();
    }



    void test(const int time){
        
        
        set_color(black);  
        delay(time);
        set_color(red); 
        delay(time);
        set_color(green); 
        delay(time);
        set_color(blue); 
        delay(time);
        set_color(white);
        delay(time);
        set_color(black); 
    }
}