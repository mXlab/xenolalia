/////////////////////////
//    LED HELPERS      //
/////////////////////////
/*
  This files contain all the functions interacting with the pixel ring
  
    void pix(int pnum, int xr, int xg, int xb)
    void strip_black()
    void strip_white()
    void strip_blue()
    void strip_red()
    void strip_green()
    void strip_yellow()
    void stripix(int xr, int xg, int xb)
  
*/
void pix(int pnum, int xr, int xg, int xb)
{
  /*
    This function set the given pixel to the given color.

    args : 
      int pnum : number of the pixel to modify
      int xr : R value of the RGB color code
      int xg : G value of the RGB color code
      int xb : B value of the RGB color code
  */
  
  strip.SetPixelColor(pnum, RgbColor(xr,xg,xb));
  strip.Show();
  
}

////////////////////////////////////
void strip_black()
{
  /*
    This function turns the whole pixel ring off.  
  */

  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, black);
  }
  strip.Show();
  
}

////////////////////////////////////
void strip_white()
{
  /*
    This function turns the whole pixel ring white.  
  */
  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, white);
  }
  strip.Show();
  
}

////////////////////////////////////
void strip_blue()
{
  /*
    This function turns the whole pixel ring blue.  
  */
  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, blue);
  }
  strip.Show();
  
}

////////////////////////////////////
void strip_red()
{
  /*
    This function turns the whole pixel ring off.  
  */
  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, red);
  }
  strip.Show();
  
}

////////////////////////////////////
void strip_green()
{
  /*
    This function turns the whole pixel ring green.  
  */
  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, green);
  }
  strip.Show();
  
}

////////////////////////////////////
void strip_yellow()
{
  /*
    This function turns the whole pixel ring yellow.  
  */
  for(int i=0; i<PixelCount; i++)
  {
    strip.SetPixelColor(i, yellow);
  }
  strip.Show();
  
}

///////////////////////////////
void stripix(int xr, int xg, int xb)
{
  /*
  This function set the whole pixel ring to the color passed in argument

  args:
    int xr: R value of the RGB color to display on the pixel ring 
    int xg: G value of the RGB color to display on the pixel ring 
    int xb: B value of the RGB color to display on the pixel ring 
  
  */
  strip_black();
  
  for(int i=0;i<PixelCount;i++){
     strip.SetPixelColor(i, RgbColor(xr,xg,xb));
     delay(10);
  }
  strip.Show();
  
}
