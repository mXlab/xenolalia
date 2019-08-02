abstract class AbstractCam {
  
  abstract void start();
  abstract boolean available();
  abstract void read();
  abstract PImage getImage();
};
