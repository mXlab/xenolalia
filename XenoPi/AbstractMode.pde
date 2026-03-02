abstract class AbstractMode {
  
  AbstractMode() { this.setup(); }
  abstract void setup();
  abstract void draw();
  
  void ready() {}
  void refreshed() {}
  void nextImage(String imagePath) {}
  void neuronsVisibility(int visClass) {}
  void testImage(String imagePath) {}
  
  void keyPressed() {}
  void mousePressed() {}
  void mouseDragged() {}
}
