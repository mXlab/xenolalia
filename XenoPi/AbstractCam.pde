abstract class AbstractCam {

  abstract void start();
  abstract void stop();
  abstract void reinitialize();
  abstract boolean available();
  abstract void read();
  abstract PImage getImage();
};
