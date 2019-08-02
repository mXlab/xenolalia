abstract class AbstractMode {
  
  AbstractMode() { this.setup(); }
  abstract void setup();
  abstract void draw();
  
  void nextImage(String imagePath) {}
  
  void keyPressed() {}
  void mousePressed() {}
  void mouseDragged() {}
}
