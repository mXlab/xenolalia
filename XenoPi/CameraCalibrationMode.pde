// This mode allows the adjustment of the camera perspective.
class CameraCalibrationMode extends AbstractMode {

  // Reference image for calibration.
  PImage referenceImg;
  
  // Used to run snapshots of reference image.
  boolean snapshotRequested;
  Timer snapshotTimer;
  final int SNAPSHOT_TIME = 250;
  
  // Input rectangle calibration.
  int mode;
  final int MODE_RECT  = 0;
  final int MODE_QUAD  = 1;
  final int MODE_CHECK = 2;
  final int N_MODES    = 3;
  
  PVector[] currentPoints; // current set of points
 
  // GUI Control parameters.
  boolean mouseCrosshair;
  boolean pointCrosshair;
  float controlSize;
  
  PImage transformedTestImage = null;

  void setup() {
    // Load points if they exist.
    settings.load();
    
    // Reference image.
    referenceImg = loadImage(REFERENCE_IMAGE);

    // Begin in input quad mode.
    mode = MODE_RECT;
    
    // Create snapshot timer.
    snapshotTimer = new Timer(SNAPSHOT_TIME);
    
    mouseCrosshair = true;
    pointCrosshair = true;
    controlSize = 5;
  }
  
  void draw() {
    // Reset.
    background(0);
    cursor();
    
    // Input rectangle mode. ///////////////////////////////////////////////////
    if (mode == MODE_RECT) {
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

      // Draw bounding box.
      strokeWeight(controlSize);
      stroke( LINE_COLOR );
      rectMode(CORNERS);
      fill(0, 0);
      rect(x1, y1, x2, y2);

      // Draw points.
      drawControlPoint(x1, y1, 0);
      drawControlPoint(x2, y2, 1);
    }
    
    // Quad points mode. ///////////////////////////////////////////////////////
    else if (mode == MODE_QUAD) {
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
      
      // Quad adjustment.
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
          // Draw line.
          strokeWeight(controlSize);
          stroke( LINE_COLOR );
          line(x, y, nx, ny);
          // Draw point.
          drawControlPoint( x, y, i );
        }
      }
    }
    
    // Check mode. ////////////////////////////////////////////////////////////
    else {
      if (transformedTestImage != null) {
        drawScaledImage(transformedTestImage);
      }
    }
    
    // Draw crosshair if needed.
    if (mode != MODE_CHECK && mouseCrosshair)
      drawCrosshair(mouseX, mouseY, color(255));
  }
  
  void testImage(String imagePath) {
    transformedTestImage = loadImage(imagePath);
  }
  
  // Draws the i-th control point.
  void drawControlPoint(float x, float y, int i) {
    fill(0, 0, 0, 0);
    strokeWeight(controlSize);
    boolean selected = (i == currentPoint);
    
    // Draw point.
    stroke( selected ? color(255, 0, 0) : color(200, 200, 200) );
    ellipse(x, y, 10, 10);
    
    // Draw crosshair.
    if (selected && pointCrosshair)
      drawCrosshair(x, y, color(0, 255, 255));
    
    // Draw text.
    fill(255);
    textSize(12 + controlSize);
    text(i+1, x, y);
  }
  
  void drawCrosshair(float x, float y, color c) {
    noCursor();
    strokeWeight(controlSize);
    stroke(c);
    line(x, 0, x, height);
    line(0, y, width, y);
  }
  
  void adjustControlSize(float adjust) {
    controlSize += adjust;
    controlSize = constrain(controlSize, 1, 50);
  }
  
  void toggleMouseCrosshair() {
    mouseCrosshair = !mouseCrosshair;
  }

  void togglePointCrosshair() {
    pointCrosshair = !pointCrosshair;
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
        case ' ':   toggleMode(); break;
        // Save settings.
        case RETURN: case ENTER: 
                    saveSettings(); break;
        // Change current control point.
        case TAB:   selectPoint( (currentPoint+1) ); break;
        case '1':   selectPoint(0); break;
        case '2':   selectPoint(1); break;
        case '3':   selectPoint(2); break;
        case '4':   selectPoint(3); break;
        
        case 'm':   toggleMouseCrosshair(); break;
        case 'p':   togglePointCrosshair(); break;
        case '+':   adjustControlSize(+1); break;
        case '-':   adjustControlSize(-1); break;
      }
    }
  }
  
  // Toggles mode.
  void toggleMode() {
    // Switch to next mode.
    mode = (mode + 1) % N_MODES;
    
    // Begin procedure.
    if (mode == MODE_QUAD) {
       // Take one snapshot.
       referenceImageSnapshot();
    }
    else if (mode == MODE_CHECK) {
      saveSettings();
      // Save image.
      String testImagePath = getTestImagePath();
      cam.getImage().save(testImagePath);
      // Ask script for test.
      OscMessage msg = new OscMessage("/xeno/euglenas/test-camera");
      msg.add(testImagePath);
      oscP5.send(msg, remoteLocation);
    }
  }
  
  void saveSettings() {
    println("Save settings!");
    // Save settings.
    settings.save();
    // Send OSC message to announce that settings have been changed.
    OscMessage msg = new OscMessage("/xeno/euglenas/settings-updated");
    oscP5.send(msg, remoteLocation);
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

  String getTestImagePath() {
    return savePath("test_camera.png");
  }
  
}
