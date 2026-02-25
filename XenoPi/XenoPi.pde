/**
 * This is the Xenolalia main sketch to be used in conjunction with xeno_osc.py.
 * It allows camera calibration as well as running the generative process in
 * inter-operability with the neural network (xeno_osc.py).
 *
 * Usage:
 * 1. Start the program. It will start in calibration mode.
 * 2. Adjust the reference image.
 *   1. Click on the first corner to place the first control point.
 *   2. Press TAB to select the next control point; then click on the 2nd corner to place it.
 *   3. You can use the arrow keys to make small adjustments.
 *   4. Once you are satisfied, press ENTER: it will save the settings.json file.
 *   5. Then press the SPACEBAR.
 * 3. Adjust the input quad.
 *   1. Using the mouse and the same keys as for the previous step, adjust the four corners of the input quad to match the corners of the image picked by the camera, directly on the screen.
 *   2. You can select one of the four control points by pressing its number (1, 2, 3, 4).
 *   3. Once you are satisfied, press ENTER: it will save the settings.json file.
 * 4. Start the xeno_osc.py script with the appropriate parameters.
 * 5. Once the xeno_osc.py script has launched and is initialized, press the 'g' key to start the generative process.
 *
 * Required Processing library: GL Video, Video (*)
 * (*) Download the most recent version, otherwise you might run into problems.
 *     Link to releases: https://github.com/processing/processing-video/releases
 *
 * The program allows to use either of these two libraries. On RPi we recommend
 * using GL Video.
 *
 * (c) Sofian Audry & TeZ
 *
 *  For use with the Raspberry Pi camera, make sure the camera is
 *  enabled in the Raspberry Pi Configuration tool and add the line
 *  "bcm2835_v4l2" d(without quotation marks) to the file
 *  /etc/modules. After a restart you should be able to see the
 *  camera device as /dev/video0.
 */
import gohai.glvideo.*;
import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress remoteLocation;
NetAddress remoteLocationServer;
NetAddress remoteLocationApparatus;
NetAddress remoteLocationLogging;

AbstractCam cam;
AbstractMode mode;
Settings settings;

final String LOGGING_IP = "192.168.0.100";
final int    LOGGING_PORT  = 8000;

// Constants.
final String SETTINGS_FILE_NAME = "settings.json";
final String REFERENCE_IMAGE = "camera_perspective_reference.png";
final color LINE_COLOR = #00ff00;

// Variables.

int currentPoint = 0;
boolean cameraRunning = true;

// Global variable that is true iff the SHIFT key is pressed.
boolean shiftPressed = false;

void setup() {
  //2592x1944
  size(1184, 624, P2D);
//  fullScreen(P2D, SPAN);

  // Load configuration file.
  settings = new Settings();

  String[] devices = GLCapture.list();
  println("Devices:");
  printArray(devices);
  String[] configs = GLCapture.configs(devices[settings.cameraId()]);
  if (devices.length > 0) {
    println("Configs:");
    printArray(configs);
  }
  
  if (devices.length == 0) {
    println("Camera not found. Verify that a camera is plugged in.");
  }
  else if (settings.cameraId() >= devices.length) {
    println("Camera devices have been found but the device number ('camera_id' property) does not exist. Double-check the 'camera_id' property in settings.json.");
  }    

  // this will use the first recognized camera by default
  // NOTE: If you run into trouble you can try changing the object
  cam = new GLCaptureCam(this, devices[settings.cameraId()], settings.cameraWidth(), settings.cameraHeight());
  //cam = new GLCaptureCam(this, devices[0], configs[0]);

  // you could be more specific also, e.g.
  //
  //video = new GLCapture(this, devices[settings.cameraId()], configs[1]);
  //video = new GLCapture(this, devices[0], 640, 480, 25);
  //video = new GLCapture(this, devices[0], configs[0]);

  cam.start();

  // Load configuration file.
  settings = new Settings();

  // Initialize mode.
  cameraCalibrationMode();

  // Setup OSC.
  oscP5 = new OscP5(this, settings.oscReceivePort());
  // xeno_osc.py on XenoPi (local)
  remoteLocation = new NetAddress(settings.oscRemoteIp(), settings.oscSendPort());
  // xeno_server.py on XenoPC
  remoteLocationServer = new NetAddress(settings.oscServerRemoteIp(), settings.oscServerSendPort());
  // apparatus on ESP32
  remoteLocationApparatus = new NetAddress(settings.oscApparatusRemoteIp(), settings.oscApparatusSendPort());
  // localhost
  remoteLocationLogging = new NetAddress(LOGGING_IP, LOGGING_PORT);
  
  oscP5.plug(this, "nextImage", "/xeno/neurons/step");
  oscP5.plug(this, "ready", "/xeno/neurons/handshake");
  oscP5.plug(this, "ready", "/xeno/neurons/begin");
  oscP5.plug(this, "testCamera", "/xeno/neurons/test-camera");  
  
  oscP5.plug(this, "refreshed", "/xeno/apparatus/refreshed");
  oscP5.plug(this, "apparatusHandshake", "/xeno/handshake");

  oscP5.plug(this, "begin", "/xeno/control/begin");

  log("XenoPi started");
}

void nextImage(String imagePath) {
  mode.nextImage(imagePath);
}

void testCamera(String imagePath) {
  mode.testImage(imagePath);
}

void ready() {
  mode.ready();
}

void refreshed() {
  log("Refreshed!");
  mode.refreshed();
}

boolean apparatusMessageReceived = false;

void apparatusHandshake() {
  apparatusMessageReceived = true;
  log("Received apparatusHandshake().");
}

void begin() {
  log("Begin generative process.");
  generativeMode();
}

void cameraCalibrationMode() {
  mode = new CameraCalibrationMode();
}

void generativeMode() {
  mode = new GenerativeMode();
}

void shapeMode() {
  mode = new ShapeMode();
}

void draw() {
  mode.draw();
}

void keyPressed() {
  // Switch mode.
  if (key == 'g')
    generativeMode();
  else if (key == 's') {
    if (mode instanceof ShapeMode)
      cameraCalibrationMode();
    else
      shapeMode();
  }
  //
  else if (key == CODED && keyCode == SHIFT)
    shiftPressed = true;
  else
    mode.keyPressed();
}

void keyReleased()  {
  if (key == CODED && keyCode == SHIFT)
    shiftPressed = false;
}

void mousePressed() {
  mode.mousePressed();
}

void mouseDragged() {
  mode.mouseDragged();
}


// Display arbitrary image in center of screen with scaling factor applied.
void drawScaledImage(PImage img) {
  if (img != null) {
    pushMatrix();
    PVector topLeft = settings.getImageRectPoint(0);
    PVector bottomRight = settings.getImageRectPoint(1);
    imageMode(CORNERS);
    image(img, topLeft.x, topLeft.y, bottomRight.x, bottomRight.y);
    popMatrix();
  }
}

void log(String message) {
  OscMessage msg = new OscMessage("/log");
  msg.add(message);
  oscP5.send(msg, remoteLocationLogging);
}

/* incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage theOscMessage) {
  /* with theOscMessage.isPlugged() you check if the osc message has already been
   * forwarded to a plugged method. if theOscMessage.isPlugged()==true, it has already
   * been forwared to another method in your sketch. theOscMessage.isPlugged() can
   * be used for double posting but is not required.
  */
  if(theOscMessage.isPlugged()==false) {
  /* print the address pattern and the typetag of the received OscMessage */
  log("### received an osc message.");
  log("### addrpattern\t"+theOscMessage.addrPattern());
  log("### typetag\t"+theOscMessage.typetag());
  }
}
