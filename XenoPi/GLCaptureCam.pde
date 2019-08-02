import gohai.glvideo.*;

class GLCaptureCam extends AbstractCam {
  
  private GLCapture cam;
  private PApplet parent;
  
  GLCaptureCam(PApplet parent, String device) {
    cam = new GLCapture(parent, device);
    this.parent = parent;
  }
  
  void start() {
    cam.play();
  }
  
  boolean available() { return cam.available(); }
  
  void read() {
    cam.read(); 
  }
  
  PImage getImage() { return cam; }
}
