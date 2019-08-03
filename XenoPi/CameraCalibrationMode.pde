// This mode allows the adjustment of the camera perspective.
class CameraCalibrationMode extends AbstractMode {

  PImage referenceImg;
  
  boolean snapshotRequested;
  
  Timer snapshotTimer;
  final int SNAPSHOT_TIME = 500;
  
  
  void setup() {
    // Load points if they exist.
    settings.load();
    
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
      for (int i=0; i<settings.nCamQuadPoints(); i++) {
        // Get point.
        PVector point = settings.getCamQuadPoint(i);
        float x = point.x;
        float y = point.y;
        // Get next point.
        int next = (i+1) % settings.nCamQuadPoints();
        PVector nextPoint = settings.getCamQuadPoint(next);
        float nx = nextPoint.x;
        float ny = nextPoint.y;
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
        case RETURN: case ENTER: 
                    settings.save(); break;
        case TAB:   selectPoint( (currentPoint+1) % settings.nCamQuadPoints()); break;
        case '1':   selectPoint(0); break;
        case '2':   selectPoint(1); break;
        case '3':   selectPoint(2); break;
        case '4':   selectPoint(3); break;
        case ' ':   referenceImageSnapshot(); break;
      }
    }
  }
  
  void mousePressed() {
    settings.getCamQuadPoint(currentPoint).set(mouseX, mouseY);
  }
  
  void mouseDragged() {
    settings.getCamQuadPoint(currentPoint).set(mouseX, mouseY);
  }
  
  void selectPoint(int i) {
    currentPoint = constrain(i, 0, settings.nCamQuadPoints()-1);
  }
  
  void movePoint(int i, float dx, float dy) {
  //  println("move point by " + dx + "," + dy);
    settings.getCamQuadPoint(i).add(dx, dy);
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
