/**
 *  Please note that the code for interfacing with Capture devices
 *  will change in future releases of this library. This is just a
 *  filler till something more permanent becomes available.
 *
 *  For use with the Raspberry Pi camera, make sure the camera is
 *  enabled in the Raspberry Pi Configuration tool and add the line
 *  "bcm2835_v4l2" (without quotation marks) to the file
 *  /etc/modules. After a restart you should be able to see the
 *  camera device as /dev/video0.
 */
 

import gohai.glvideo.*;
GLCapture video;

final String CONFIG_FILE_SAVE = "camera_perspective.conf";
final int SCALING_FACTOR = 2;
final int CAM_WIDTH = 320;
final int CAM_HEIGHT = 200;

int currentPoint = 0;
final int N_POINTS = 4;
PVector[] points = new PVector[N_POINTS];

void setup() {
  //2592x1944
  size(640, 400, P2D);

  String[] devices = GLCapture.list();
  println("Devices:");
  printArray(devices);
  if (0 < devices.length) {
    String[] configs = GLCapture.configs(devices[0]);
    println("Configs:");
    printArray(configs);
  }

  // this will use the first recognized camera by default
  video = new GLCapture(this);

  // you could be more specific also, e.g.
  //video = new GLCapture(this, devices[0]);
  //video = new GLCapture(this, devices[0], 640, 480, 25);
  //video = new GLCapture(this, devices[0], configs[0]);

  video.play();
  
  // Initialize positions.
  points[0] = new PVector(0, 0);
  points[1] = new PVector(0, height);
  points[2] = new PVector(width, height);
  points[3] = new PVector(width, 0);
}

void draw() {
  background(0);
  
  // Draw video.
  if (video.available()) {
    video.read();
  }
  image(video, 0, 0, width, height);
  
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
    stroke( color(200, 200, 200) );
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