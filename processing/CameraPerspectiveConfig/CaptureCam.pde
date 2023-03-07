import processing.video.*;

class CaptureCam extends AbstractCam {
  
  private Capture cam;
  private PApplet parent;
  
  CaptureCam(PApplet parent, String device) {
    cam = new Capture(parent, device);
    this.parent = parent;
  }
  
  void start() {
    cam.start();
  }
  
  boolean available() { return cam.available(); }
  
  void read() {
    cam.read(); 
  }
  
  void draw() {
    parent.image(cam, 0, 0, parent.width, parent.height);
  }

}
