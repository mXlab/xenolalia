abstract class AbstractMode {
  
  AbstractMode() { this.setup(); }
  abstract void setup();
  abstract void draw();
  
  void ready() {}
  void nextImage(String imagePath) {}
  void testImage(String imagePath) {}
  
  void keyPressed() {}
  void mousePressed() {}
  void mouseDragged() {}
}
