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

// Persistent ShapeMode instance so its state survives mode switches.
ShapeMode _shapeMode = null;

// Mode to restore when exiting ShapeMode with 'x'.
AbstractMode _previousMode = null;

void setup() {
  //2592x1944
  size(1184, 624, P2D);
//  fullScreen(P2D, SPAN);

  // Load configuration file.
  settings = new Settings();

  try {
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

    cam.start();
  } catch (Throwable e) {
    println("Camera initialization failed: " + e.getMessage());
    println("Running without camera (calibration / symbol mode only).");
    cam = new NullCam();
  }

  // Load configuration file.
  settings = new Settings();

  // Setup OSC first — mode initialization calls log() which needs oscP5.
  oscP5 = new OscP5(this, settings.oscReceivePort());
  // xeno_osc.py on XenoPi (local)
  remoteLocation = new NetAddress(settings.oscRemoteIp(), settings.oscSendPort());
  // xeno_server.py on XenoPC
  remoteLocationServer = new NetAddress(settings.oscServerRemoteIp(), settings.oscServerSendPort());
  // apparatus on ESP32
  remoteLocationApparatus = new NetAddress(settings.oscApparatusRemoteIp(), settings.oscApparatusSendPort());
  // localhost
  remoteLocationLogging = new NetAddress(LOGGING_IP, LOGGING_PORT);

  // Initialize mode based on startup_mode setting.
  String sm = settings.startupMode();
  if (sm.equals("generative"))
    generativeMode();
  else if (sm.equals("idle"))
    idleMode();
  else if (sm.equals("resume"))
    resumeMode();
  else // "calibration" or unrecognized value
    cameraCalibrationMode();
  
  oscP5.plug(this, "nextImage", "/xeno/neurons/step");
  oscP5.plug(this, "ready", "/xeno/neurons/handshake");
  oscP5.plug(this, "ready", "/xeno/neurons/begin");
  oscP5.plug(this, "testCamera", "/xeno/neurons/test-camera");
  oscP5.plug(this, "neuronsVisibility", "/xeno/neurons/visibility");
  
  oscP5.plug(this, "refreshed", "/xeno/apparatus/refreshed");
  oscP5.plug(this, "apparatusHandshake", "/xeno/handshake");

  oscP5.plug(this, "begin", "/xeno/control/begin");
  oscP5.plug(this, "stop",  "/xeno/control/stop");

  log("XenoPi started");
}

void nextImage(String imagePath) {
  mode.nextImage(imagePath);
}

void neuronsVisibility(int visClass) {
  mode.neuronsVisibility(visClass);
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

void stop() {
  log("Stop generative process.");
  if (mode instanceof GenerativeMode)
    ((GenerativeMode)mode).requestStop();
}

void cameraCalibrationMode() {
  mode = new CameraCalibrationMode();
}

void generativeMode() {
  if (cam instanceof NullCam) {
    mode = new NoCameraMode();
    return;
  }
  mode = new GenerativeMode();
}

// Exhibition standby: black screen until /xeno/control/begin arrives.
void idleMode() {
  if (cam instanceof NullCam) {
    mode = new NoCameraMode();
    return;
  }
  mode = new GenerativeMode();
  ((GenerativeMode)mode).startIdle();
}

// Attempt to resume the last experiment from recovery_state.json.
// Falls back to idleMode() if recovery is absent or the state is not resumable.
void resumeMode() {
  if (cam instanceof NullCam) {
    mode = new NoCameraMode();
    return;
  }
  JSONObject recovery = null;
  try {
    recovery = loadJSONObject(savePath("recovery_state.json"));
  } catch (Exception e) {
    println("Resume: no recovery file found (" + e.getMessage() + ").");
  }
  if (recovery == null) {
    println("Resume: no recovery file found — starting in idle mode.");
    idleMode();
    return;
  }
  String savedState = recovery.getString("state", "");
  boolean hasUid = recovery.hasKey("experiment_uid");

  if (!hasUid) {
    // No experiment started yet (crashed during base image capture).
    if (savedState.equals("FLASH") || savedState.equals("SNAPSHOT")) {
      println("Resume: crashed during base image capture — restarting from FLASH.");
      mode = new GenerativeMode();
      ((GenerativeMode)mode).startResumeBaseImage();
    } else {
      println("Resume: no valid recovery state — starting in idle mode.");
      idleMode();
    }
    return;
  }

  // Experiment uid present — resume mid-experiment.
  // MAIN and WAIT_FOR_GLYPH resume directly to MAIN.
  // FLASH and SNAPSHOT re-enter at FLASH so the missed snapshot is retaken.
  State resumeTarget;
  if (savedState.equals("MAIN") || savedState.equals("WAIT_FOR_GLYPH"))
    resumeTarget = State.MAIN;
  else if (savedState.equals("FLASH") || savedState.equals("SNAPSHOT"))
    resumeTarget = State.FLASH;
  else {
    println("Resume: state '" + savedState + "' is not resumable — starting in idle mode.");
    idleMode();
    return;
  }
  println("Resume: restoring experiment '" + recovery.getString("experiment_uid") + "' from " + savedState + " → entering " + resumeTarget);
  mode = new GenerativeMode();
  ((GenerativeMode)mode).startResume(recovery, resumeTarget);
}

void shapeMode() {
  if (_shapeMode == null)
    _shapeMode = new ShapeMode();
  mode = _shapeMode;
}

void draw() {
  mode.draw();
}

void keyPressed() {
  // Switch mode.
  if (key == 'g')
    generativeMode();
  else if (key == 'k')
    cameraCalibrationMode();
  else if (key == 'x') {
    if (mode instanceof ShapeMode) {
      // Exit ShapeMode: restore the mode we came from.
      mode = (_previousMode != null) ? _previousMode : mode;
      _previousMode = null;
    } else {
      // Enter ShapeMode: remember where we came from.
      _previousMode = mode;
      shapeMode();
    }
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
