#include "pixel_ring.hpp"
#include <pins.h>


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