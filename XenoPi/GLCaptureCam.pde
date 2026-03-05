import gohai.glvideo.*;

class GLCaptureCam extends AbstractCam {

  private GLCapture cam;
  private PApplet parent;
  private String deviceName;
  private int w, h;
  boolean isError = false; // set true on any camera exception; triggers watchdog immediately

  GLCaptureCam(PApplet parent, String device, int w, int h) {
//    cam = new GLCapture(parent, device);
//    cam = new GLCapture(parent, device, config);
    cam = new GLCapture(parent, device, w, h);
    this.parent = parent;
    this.deviceName = device;
    this.w = w;
    this.h = h;
  }

  GLCaptureCam(PApplet parent, String device, String config) {
//    cam = new GLCapture(parent, device);
    cam = new GLCapture(parent, device, config);
    this.parent = parent;
    this.deviceName = device;
    this.w = -1;
    this.h = -1;
  }

  void start() {
    cam.start();
  }

  void stop() {
    try { cam.dispose(); } catch (Throwable e) { println("Camera stop error: " + e.getMessage()); }
  }

  // Re-enumerate devices and create a fresh capture pipeline.
  // Matches by device name so it survives USB re-enumeration with a new /dev/videoN path.
  void reinitialize() {
    stop();
    delay(500); // give the OS time to fully release the device

    String[] devices = GLCapture.list();
    String foundDevice = deviceName; // fallback: same name (GStreamer resolves the path)
    for (String d : devices) {
      if (d.equals(deviceName)) {
        foundDevice = d;
        break;
      }
    }

    println("Camera reinitialize: connecting to '" + foundDevice + "'");
    try {
      if (w > 0 && h > 0)
        cam = new GLCapture(parent, foundDevice, w, h);
      else
        cam = new GLCapture(parent, foundDevice);
      cam.start();
      isError = false;
    } catch (Throwable e) {
      println("Camera reinitialize failed: " + e.getMessage());
    }
  }
  
  boolean available() {
    if (isError) return false;
    try { return cam.available(); }
    catch (Throwable e) { println("Camera error (available): " + e.getMessage()); isError = true; return false; }
  }

  void read() {
    if (isError) return;
    try { cam.read(); }
    catch (Throwable e) { println("Camera error (read): " + e.getMessage()); isError = true; }
  }
  
  PImage getImage() { return cam; }
}
