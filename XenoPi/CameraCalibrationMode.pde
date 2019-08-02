// This mode allows the adjustment of the camera perspective.
class CameraCalibrationMode extends AbstractMode {

  PImage referenceImg;
  
  boolean snapshotRequested;
  
  Timer snapshotTimer;
  final int SNAPSHOT_TIME = 500;
  
  void setup() {
    // Load points if they exist.
    loadPoints();
    
    // Reference image.
    referenceImg = loadImage(REFERENCE_IMAGE);
    
    snapshotTimer = new Timer(SNAPSHOT_TIME);

    // Take one snapshot.
    referenceImageSnapshot();
  }
  
  void draw() {
    background(0);
  
    imageMode(CORNER);
    
    // Draw video.
    if (snapshotRequested) {
      drawReferenceImage();
      if (snapshotTimer.isFinished() &&
          cam.available()) {
        cam.read(); // take snapshot
        snapshotRequested = false;
      }
    }
    else {
      // Draw image fullscreen image from camera.
      image(cam.getImage(), 0, 0, width, height);
      
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
        case ' ':   referenceImageSnapshot(); break;
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
  //  println("move point by " + dx + "," + dy);
    points[i].add(dx, dy);
  }
  
  // Take a snapshot of reference image with the camera.
  void referenceImageSnapshot() {
    snapshotRequested = true;
    snapshotTimer.start();
  }
  
  void drawReferenceImage() {
    // Draw reference image.
    drawScaledImage(referenceImg);
  }
  
}
