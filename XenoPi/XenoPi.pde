/** 
 * This is the Xenolalia main sketch to be used in conjunction with xeno_osc.py.
 * It allows camera calibration as well as running the generative process in 
 * inter-operability with the neural network (xeno_osc.py).
 *
 * Usage:
 * - Start the sketch. It will start in calibration mode.
 * - Click on the first corner to place the first control point.
 * - Press TAB to select the next control point; then click on the 2nd corner to place it.
 * - Repeat operation for corners 3 & 4.
 * - You can select one of the four control points by pressing its number (1, 2, 3, 4).
 * - You can adjust more precisely by using the arrow keys.
 * - Once you are satisfied, press ENTER: it will save the camera_perspective.conf file.
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
 *  "bcm2835_v4l2" (without quotation marks) to the file
 *  /etc/modules. After a restart you should be able to see the
 *  camera device as /dev/video0.
 */
import gohai.glvideo.*;
import gab.opencv.*;
import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress remoteLocation;
OpenCV opencv;

AbstractCam cam;

// Edit these values to match camera specs.
final int DEVICE_ID = 0;
final int CAM_WIDTH = 640;
final int CAM_HEIGHT = 480;

final int OPEN_CV_WIDTH = 320;
final int OPEN_CV_HEIGHT = 320;

final String CAMERA_PERSPECTIVE_FILE_NAME = "camera_perspective.conf";

final String REFERENCE_IMAGE = "camera_perspective_reference.png";

final color LINE_COLOR = #00ff00;

// Set to true to let the euglenas begin, otherwise the neural net will.
final boolean EUGLENAS_BEGIN = false;

int currentPoint = 0;
final int N_POINTS = 4;
PVector[] points = new PVector[N_POINTS];

final int OSC_PORT_SEND = 7000;
final int OSC_PORT_RECV = 7001;
final String OSC_IP = "127.0.0.1"; // localhost

// Adjust this so that the image fits right inside the petri dish when viewed
// from the camera.
float IMAGE_SCALE = 0.35; // scaling ratio

boolean cameraRunning = true;

AbstractMode mode;

void setup() {
  //2592x1944
  //size(640, 400, P2D);
  fullScreen(P2D);

  String[] devices = GLCapture.list();
  println("Devices:");
  printArray(devices);
  String[] configs = GLCapture.configs(devices[DEVICE_ID]);
  if (devices.length > 0) {
    println("Configs:");
    printArray(configs);
  }

  // this will use the first recognized camera by default
  // NOTE: If you run into trouble you can try changing the object
  cam = new GLCaptureCam(this, devices[DEVICE_ID]);
  //cam = new CaptureCam(this, devices[DEVICE_ID]);

  // you could be more specific also, e.g.
  //
  //video = new GLCapture(this, devices[DEVICE_ID], configs[1]);
  //video = new GLCapture(this, devices[0], 640, 480, 25);
  //video = new GLCapture(this, devices[0], configs[0]);

  cam.start();
  
  // opencv = new OpenCV(this, width, height);
  opencv = new OpenCV(this, OPEN_CV_WIDTH, OPEN_CV_HEIGHT);
  
  // Initialize mode.
  mode = new CameraCalibrationMode();
//  mode.setup();

  // Setup OSC.
  oscP5 = new OscP5(this, OSC_PORT_RECV);  
  remoteLocation = new NetAddress(OSC_IP, OSC_PORT_SEND);
  
  oscP5.plug(this, "nextImage", "/xeno/neurons/step");
}

void nextImage(String imagePath) {
  mode.nextImage(imagePath);
}

void draw() {
  mode.draw();
}

void keyPressed() {
  // Switch mode.
  if (key == 'C')
    mode = new CameraCalibrationMode();
  else if (key == 'G')
    mode = new GenerativeMode();
  // 
  else
    mode.keyPressed();
}

void mousePressed() {
  mode.mousePressed();
}

void mouseDragged() {
  mode.mouseDragged();
}

// Camera perspective configuration. //////////////////////

void savePoints() {
  String[] strConfig = new String[N_POINTS*2];
  int k=0;
  for (int i=0; i<N_POINTS; i++) {
    PVector p = points[i];
    float x = p.x / width;
    float y = p.y / height;
    strConfig[k++] = nf(x);
    strConfig[k++] = nf(y);
    print(x + ", " + y + ", ");
  }
  // Save array of strings straight to file.
  saveStrings(CAMERA_PERSPECTIVE_FILE_NAME, strConfig);
}

void loadPoints() {
  try {
    String[] strConfig = loadStrings(CAMERA_PERSPECTIVE_FILE_NAME);
    for (int i=0; i<N_POINTS; i++) {
      points[i] = new PVector(float(strConfig[i*2])*width, float(strConfig[i*2+1])*height);
    }
  } catch (Exception e) {
    println("Problem when loading camera perspective configuration file: " + e);
    // File not found: reset points.
    resetPoints();
  }
}

void resetPoints() {
  // Initialize positions.
  points[0] = new PVector(0, 0);
  points[1] = new PVector(0, height);
  points[2] = new PVector(width, height);
  points[3] = new PVector(width, 0);
}

// Display arbitrary image in center of screen with scaling factor applied.
void drawScaledImage(PImage img) {
  pushMatrix();
  int minDim = round(IMAGE_SCALE * min(width, height));
  imageMode(CENTER);
  image(img, width/2, height/2, minDim, minDim);
  popMatrix();
}

String generateUniqueBaseName() {
  return nf(year(),4)+"-"+nf(month(),2)+"-"+nf(day(),2)+"_"+
           nf(hour(),2)+":"+nf(minute(),2)+":"+nf(second(),2)+"_"+nf(millis(),6);
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
  println("### received an osc message.");
  println("### addrpattern\t"+theOscMessage.addrPattern());
  println("### typetag\t"+theOscMessage.typetag());
  }
}
