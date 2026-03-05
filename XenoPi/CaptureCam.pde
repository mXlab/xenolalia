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

  void stop() {
    try { cam.stop(); } catch (Throwable e) { println("Camera stop error: " + e.getMessage()); }
  }

  void reinitialize() {
    stop();
    delay(500);
    String[] devices = Capture.list();
    println("Camera reinitialize: reconnecting CaptureCam");
    try {
      cam = new Capture(parent, devices.length > 0 ? devices[0] : "");
      cam.start();
    } catch (Throwable e) {
      println("Camera reinitialize failed: " + e.getMessage());
    }
  }

  boolean available() { return cam.available(); }
  
  void read() {
    cam.read(); 
  }
  
  PImage getImage() { return cam; }

}
