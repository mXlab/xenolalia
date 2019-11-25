// This mode runs the generative process through interoperability
// with python script.
class GenerativeMode extends AbstractMode {
  
  // The "glyph" image currently displayed in background.
  PImage img;
  
  // Status flags.
  boolean flash = false;
  boolean camView = false;
  boolean autoMode = true;
  
  // Corner cam dimensions.
  final int CAM_VIEW_WIDTH = 200;
  final int CAM_VIEW_HEIGHT = 200;
  
  // Base colors.
  final color FLASH_COLOR = color(255);    
  final color PROJECTION_COLOR = color(#ff00ff); // magenta
  
  // OpenCV processed image.
  PImage processedImage;
  
  // Snapshot-related.
  boolean snapshotRequested;
  int nSnapshots;
  Timer exposureTimer;

  // Controls exposure time (time between each snapshot)
  final int EXPOSURE_TIME = 1 * (60000);

  // Used during capture to go through different phases.
  int capturePhase;
  
  // Unique experiment name (to save images).
  String experimentName;
  
  // Basic contrast (for filtering).
  float contrast = 2.0;

  void setup() {
    // Create a unique name for experiment.
    experimentName = generateUniqueBaseName();
    
    // Take a first snapshot.
    nSnapshots = 0;
    exposureTimer = new Timer(EXPOSURE_TIME);
    requestSnapshot();
    exposureTimer.start();

    // Create processed image canvas.
    processedImage = createImage(OPEN_CV_WIDTH, OPEN_CV_WIDTH, RGB);
  }

  ///////////////////////////////////////
  void draw() {
  
    // Capture video.
    if (cam.available()) {
      // Update video frame.
      cam.read();
    }
    
    // Snapshot request.
    if (snapshotRequested) {
      //processImage();
      captureLoop();
    }
    
    // Project current iteration.
    else {
      
      // In auto-mode: collect snapshots at a regular pace.
      if (autoMode && exposureTimer.isFinished()) {
        requestSnapshot();
        exposureTimer.start();
      }
      
      // Display background or projected image depending on flash status.
      if (flash) { // flash!
        background(FLASH_COLOR);
      } else { // projected image
        background(0);
        tint(PROJECTION_COLOR); // tint
        drawScaledImage(img);
      }
      
      // Camera view in the top-left corner.
      if (camView) {
        noTint();
        imageMode(CORNER);
        image(cam.getImage(), 0, 0, CAM_VIEW_WIDTH, CAM_VIEW_HEIGHT);
      }
      
      // Display help text.
      fill(255);
      textSize(32);
      String status;
      if (autoMode)
        status = "time until next snapshot: " + nf(exposureTimer.countdownTime()/1000.0f, 3, 1) + " s";
      else
        status = "manual mode";
      text(status, 10, height-10);
      
    }
  }
  
  // Capture image loop (FSM).
  void captureLoop() {
  
    println("capture loop");
    if (capturePhase==0)
    {
      capturePhase = 1;
      background(FLASH_COLOR);
      cam.read();
    }
    
    else if (capturePhase==1) {    
      background(FLASH_COLOR);
      capturePhase = 2;
      delay(1000);
    }
    
    else if (capturePhase==2) {
      snapshot();
      delay(1000);
      capturePhase = 3; // will wait for response
    }
  }
  
  void keyPressed() {
    // Force snapshot.
    if (key == ' ')
      requestSnapshot();
      
    // Toggle flash.
    else if (key == 'f')
      flash = !flash;
      
    // Toggle cam view.
    else if (key == 'v')
      camView = !camView;
      
    // Toggle auto-mode.
    else if (key == 'a') {
      autoMode = !autoMode;
    }
  }  
  

  // Take a snapshot of reference image with the camera.
  void requestSnapshot() {
    println("Snapshot requested");
    snapshotRequested = true;
//    snapshotTimer.start();
    capturePhase = 0;
  }
  
  // Called when receiving OSC message.
  void nextImage(String imagePath) {
    img = loadImage(imagePath);
    snapshotRequested = false;
  }
  
  // Create filtered image using OpenCV.
  void processImage() {
    // Load the new frame of our camera in to OpenCV
    opencv.loadImage(cam.getImage());
    opencv.contrast(contrast);
    processedImage = opencv.getSnapshot();
  }
  
  // Saves snapshot to disk and sends OSC message to announce 
  // creation of new image.
  void snapshot() {
    // Generate image paths.
    String basename = "snapshot_"+nSnapshots+"_"+nf(millis(), 6);
    String prefix = "snapshots/"+experimentName+"/"+basename;
//    String processedImageFilename = savePath(prefix+"_pro.png");
    String rawImageFilename = savePath(prefix+"_raw.png");
    //processedImage.save(processedImageFilename);
    cam.getImage().save(rawImageFilename);
    
    // Send an OSC message to announce creation of new image.
    OscMessage msg = new OscMessage("/xeno/euglenas/" + 
      ((nSnapshots == 0 && !EUGLENAS_BEGIN) ? "begin" : "step"));
//    msg.add(processedImageFilename);
    msg.add(rawImageFilename);
    
    oscP5.send(msg, remoteLocation);
    
    // Update snapshot counter.
    nSnapshots++;
  }
}
