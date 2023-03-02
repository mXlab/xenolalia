/** 
 * This program allows to find the 4 corners of the projected image in order
 * to crop and unskew it. It creates a camera_perspective.conf file to be used
 * in conjunction with the other programs.
 *
 * Usage:
 * - Start the sketch.
 * - Press 'r' to show only the reference image.
 * - Press 's' to pause the camera (it will take a snapshot of ref image).
 * - Press 'c' to show only the camera image.
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
 * (c) Sofian Audry
 *
 *  For use with the Raspberry Pi camera, make sure the camera is
 *  enabled in the Raspberry Pi Configuration tool and add the line
 *  "bcm2835_v4l2" (without quotation marks) to the file
 *  /etc/modules. After a restart you should be able to see the
 *  camera device as /dev/video0.
 */
import gohai.glvideo.*;

AbstractCam cam;

// Edit these values to match camera specs.
final int DEVICE_ID = 1;
final int CAM_WIDTH = 640;
final int CAM_HEIGHT = 480;

final String CONFIG_FILE_SAVE = "camera_perspective.conf";

final String REFERENCE_IMAGE = "camera_perspective_reference.png";

final color LINE_COLOR = #00ff00;

int currentPoint = 0;
final int N_POINTS = 4;
PVector[] points = new PVector[N_POINTS];

PImage referenceImg;
int referenceAlpha;

boolean cameraRunning = true;

void setup() {
  //2592x1944
  size(640, 400, P2D);

  String[] devices = GLCapture.list();
  println("Devices:");
  printArray(devices);
  String[] configs = GLCapture.configs(devices[DEVICE_ID]);
  if (0 < devices.length) {
    println("Configs:");
    printArray(configs);
  }

  // this will use the first recognized camera by default
  // NOTE: If you run into trouble you can try changing the object
  //cam = new GLCaptureCam(this, devices[DEVICE_ID]);
  cam = new CaptureCam(this, devices[DEVICE_ID]);

  // you could be more specific also, e.g.
  //
  //video = new GLCapture(this, devices[DEVICE_ID], configs[1]);
  //video = new GLCapture(this, devices[0], 640, 480, 25);
  //video = new GLCapture(this, devices[0], configs[0]);

  cam.start();

  // Initialize positions.
  points[0] = new PVector(0, 0);
  points[1] = new PVector(0, height);
  points[2] = new PVector(width, height);
  points[3] = new PVector(width, 0);
  
  // Reference image.
  referenceImg = loadImage(REFERENCE_IMAGE);
  setReferenceAlpha(128);
}

void draw() {
  background(0);
  
  imageMode(CORNER);
  // Draw video.
  if (cam.available() && cameraRunning) {
    cam.read();
  }
  cam.draw();
  
  // Draw reference image.
  int minDim = min(width, height);
  imageMode(CENTER);
  image(referenceImg, width/2, height/2, minDim, minDim);

  // Draw controls.
  for (int i=0; i<N_POINTS; i++) {
    float x = points[i].x;
    float y = points[i].y;
    int next = (i+1) % N_POINTS;
    float nx = points[next].x;
    float ny = points[next].y;
    // Draw point.
    fill(0, 0, 0, 0);
    stroke( i == currentPoint ? color(200, 0, 0) : color(200, 200, 200) );
    ellipse(x, y, 10, 10);
    fill(255);
    text(i+1, x, y);
    // Draw line.
    stroke( LINE_COLOR );
    line(x, y, nx, ny);
  }
}

void keyPressed() {
  if (key == CODED) {
    switch (keyCode) {
      case UP:     movePoint(currentPoint, 0, -1); break;
      case DOWN:   movePoint(currentPoint, 0, +1); break;
      case LEFT:   movePoint(currentPoint, -1, 0); break;
      case RIGHT:  movePoint(currentPoint, +1, 0); break;
    }
  }
  else {
    switch (key) {
      case RETURN:
      case ENTER: savePoints(); break;
      case TAB:   selectPoint( (currentPoint+1) % N_POINTS); break;
      case '1':   selectPoint(0); break;
      case '2':   selectPoint(1); break;
      case '3':   selectPoint(2); break;
      case '4':   selectPoint(3); break;
      case '+':   setReferenceAlpha(referenceAlpha + 64); break;
      case '-':   setReferenceAlpha(referenceAlpha - 64); break;
      case 'r':   setReferenceAlpha(255); break;
      case 'c':   setReferenceAlpha(0); break;
      case 's':   toggleCamera(); break;
    }
  }
}

void mousePressed() {
  points[currentPoint].set(mouseX, mouseY);
}

void mouseDragged() {
  points[currentPoint].set(mouseX, mouseY);
}

void selectPoint(int i) {
  currentPoint = constrain(i, 0, N_POINTS-1);
}

void setReferenceAlpha(int alpha) {
  // Set transparency of reference image.
  referenceAlpha = constrain(alpha, 0, 255);
  int[] mask = new int[referenceImg.width*referenceImg.height];
  for (int i=0; i<mask.length; i++)
    mask[i] = referenceAlpha;
  referenceImg.mask(mask);
}

void toggleCamera() {
  cameraRunning = !cameraRunning;
}

void movePoint(int i, float dx, float dy) {
  println("move point by " + dx + "," + dy);
  points[i].add(dx, dy);
}

void savePoints() {
  String[] strConfig = new String[N_POINTS*2];
  int k=0;
  for (int i=0; i<N_POINTS; i++) {
    PVector p = points[i];
    p.x /= width;
    p.y /= height;
    strConfig[k++] = nf(p.x);
    strConfig[k++] = nf(p.y);
    print(p.x + ", " + p.y + ", ");
  }
  saveStrings(CONFIG_FILE_SAVE, strConfig);
}
