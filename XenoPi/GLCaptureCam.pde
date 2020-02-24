import gohai.glvideo.*;

class GLCaptureCam extends AbstractCam {
  
  private GLCapture cam;
  private PApplet parent;
  
  GLCaptureCam(PApplet parent, String device) {
    cam = new GLCapture(parent, device);
//    cam = new GLCapture(parent, device, OPEN_CV_WIDTH, OPEN_CV_HEIGHT);
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
