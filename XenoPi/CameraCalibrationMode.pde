// This mode allows the adjustment of the camera perspective.
class CameraCalibrationMode extends AbstractMode {

  // Reference image for calibration.
  PImage referenceImg;
  
  // Used to run snapshots of reference image.
  boolean snapshotRequested;
  Timer snapshotTimer;
  final int SNAPSHOT_TIME = 250;
  
  // Input rectangle calibration.
  boolean inputRectMode;
  PVector[] currentPoints; // current set of points
  
  void setup() {
    // Load points if they exist.
    settings.load();
    
    // Reference image.
    referenceImg = loadImage(REFERENCE_IMAGE);

    // Begin in input quad mode.
    inputRectMode = true;
    
    // Create snapshot timer.
    snapshotTimer = new Timer(SNAPSHOT_TIME);
  }
  
  void draw() {
    // Reset.
    background(0);
    
    // Input rectangle mode.
    if (inputRectMode) {
      // Gather control points.
      currentPoints = settings.getImageRectPoints();
      
      // Draw reference image.
      drawReferenceImage();

      // We are just using the top left and bottom right points in that mode.
      PVector topLeft = settings.getImageRectPoint(0);
      PVector bottomRight = settings.getImageRectPoint(1);
      float x1 = topLeft.x;
      float y1 = topLeft.y;
      float x2 = bottomRight.x;
      float y2 = bottomRight.y;

      // Draw points.
      drawControlPoint(x1, y1, 0);
      drawControlPoint(x2, y2, 1);
      // Draw bounding box.
      stroke( LINE_COLOR );
      rectMode(CORNERS);
      fill(0, 0);
      rect(x1, y1, x2, y2);
    }
    
    // Quad points mode.
    else {
      // Gather control points.
      currentPoints = settings.getCamQuadPoints();
    
      // Snapshot mode.
      if (snapshotRequested) {
        drawReferenceImage();
        if (cam.available()) {
          cam.read();
        }
        if (snapshotTimer.isFinished()) {
          snapshotRequested = false;
        }
      }
      
      // Quad adjustment mode.
      else {
        // Draw image fullscreen image from camera.
        imageMode(CORNER);
        image(cam.getImage(), 0, 0, width, height);
  //      image(cam.getImage(), 0, 0);
        
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
          drawControlPoint( x, y, i );
          // Draw line.
          stroke( LINE_COLOR );
          line(x, y, nx, ny);
        }
      }
    }
  }
  
  // Draws the i-th control point.
  void drawControlPoint(float x, float y, int i) {
    fill(0, 0, 0, 0);
    stroke( i == currentPoint ? color(200, 0, 0) : color(200, 200, 200) );
    ellipse(x, y, 10, 10);
    fill(255);
    text(i+1, x, y);
  }
  
  void keyPressed() {
    if (key == CODED) {
      switch (keyCode) {
        // Move points by small steps.
        case UP:     movePoint(currentPoint, 0, -1); break;
        case DOWN:   movePoint(currentPoint, 0, +1); break;
        case LEFT:   movePoint(currentPoint, -1, 0); break;
        case RIGHT:  movePoint(currentPoint, +1, 0); break;
      }
    }
    else {
      switch (key) {
        // Change mode.
        case ' ': toggleMode(); break;
        // Save settings.
        case RETURN: case ENTER: 
                    settings.save(); break;
        // Change current control point.
        case TAB:   selectPoint( (currentPoint+1) ); break;
        case '1':   selectPoint(0); break;
        case '2':   selectPoint(1); break;
        case '3':   selectPoint(2); break;
        case '4':   selectPoint(3); break;
      }
    }
  }
  
  // Toggles mode.
  void toggleMode() {
    inputRectMode = !inputRectMode;
    if (!inputRectMode) {
       // Take one snapshot.
       referenceImageSnapshot();
    }
  }
  
  void mousePressed() {
    currentPoints[currentPoint].set(mouseX, mouseY);
  }
  
  void mouseDragged() {
    currentPoints[currentPoint].set(mouseX, mouseY);
  }
  
  // Select given point (wraps around).
  void selectPoint(int i) {
    currentPoint = constrain(i % currentPoints.length, 0, currentPoints.length-1);
  }
  
  void movePoint(int i, float dx, float dy) {
  //  println("move point by " + dx + "," + dy);
    currentPoints[i].add(dx, dy);
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
