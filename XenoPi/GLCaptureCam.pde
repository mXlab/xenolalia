import gohai.glvideo.*;

class GLCaptureCam extends AbstractCam {
  
  private GLCapture cam;
  private PApplet parent;
  
  GLCaptureCam(PApplet parent, String device, int w, int h) {
//    cam = new GLCapture(parent, device);
//    cam = new GLCapture(parent, device, config);
    cam = new GLCapture(parent, device, w, h);
    this.parent = parent;
  }

    GLCaptureCam(PApplet parent, String device, String config) {
//    cam = new GLCapture(parent, device);
    cam = new GLCapture(parent, device, config);
    this.parent = parent;
  }

  void start() {
    cam.start();
  }
  
  boolean available() { return cam.available(); }
  
  void read() {
    cam.read(); 
  }
  
  PImage getImage() { return cam; }
}
