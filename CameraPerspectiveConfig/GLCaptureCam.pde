import gohai.glvideo.*;

class GLCaptureCam extends AbstractCam {
  
  private GLCapture cam;
  private PApplet parent;
  
  GLCaptureCam(PApplet parent, String device) {
    cam = new GLCapture(parent, device);
  }
  
  void start() {
    cam.play();
  }
  
  boolean available() { return cam.available(); }
  
  void read() {
    cam.read(); 
  }
  
  void draw() {
    parent.image(cam, 0, 0, parent.width, parent.height);
  }

}
