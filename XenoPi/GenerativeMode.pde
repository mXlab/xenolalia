
// This mode runs the generative process through interoperability
// with python script.
class GenerativeMode extends AbstractMode {

  // The "glyph" image currently displayed in background.
  PImage glyph;

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
  final color PROJECTION_BACKGROUND_COLOR = color(0);

  // Capture FSM state enum.
  final int CAPTURE_FLASH = 0;
  final int CAPTURE_FLASH_WAIT  = 1;
  final int CAPTURE_SNAPSHOT = 2;
  final int CAPTURE_SNAPSHOT_WAIT = 3;
  final int CAPTURE_DONE = 4;

  // Snapshot-related.
  boolean snapshotRequested;
  Timer exposureTimer;
  Timer captureTimer;

  // Used during capture to go through different phases.
  int capturePhase;

  // Experiment manager.
  Experiment experiment;
  int nExperiments;

  PImage baseImage;

  boolean neuronsReady;
  boolean baseImageRecorded;
  
  void setup() {
    neuronsReady = false;
    baseImageRecorded = false;
    nExperiments = -1;
    
    // For first flash: record base image.
    background(FLASH_COLOR);
    requestSnapshot();
  }

  void draw() {
    // Remove annoying cursor.
    noCursor();
    
    // Record base image.
    if (!baseImageRecorded) {
      background(FLASH_COLOR);
      while (cam.available())
        cam.read();
        
      if (capturePhase != CAPTURE_DONE)
        captureLoop();
      else {
        snapshot(true);
        baseImageRecorded = true;
      }
    }

    // Not ready.
    else if (!neuronsReady) {
      background(0);
      fill(255);
      textSize(32);
      text("Waiting for xeno_osc.py response", 10, height-10);
      
      // Send handshake.
      OscMessage msg = new OscMessage("/xeno/euglenas/handshake");
      oscP5.send(msg, remoteLocation);
      delay(100);
    }

    else {
      // Capture video.
      if (cam.available()) {
        // Update video frame.
        cam.read();
      }
  
      // Snapshot request.
      if (snapshotRequested || capturePhase != CAPTURE_DONE) {
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
          background(PROJECTION_BACKGROUND_COLOR);
          tint(PROJECTION_COLOR); // tint
          drawScaledImage(glyph);
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
        String status = "exp # " + nExperiments + "  ";
        if (autoMode)
          status += "auto mode: " + nf(exposureTimer.countdownTime()/1000.0f, 3, 1) + " s";
        else
          status += "manual mode";
        text(status, 10, height-10);
      }
    }
  }

  void startCaptureLoop() {
    capturePhase = CAPTURE_FLASH;
    captureTimer = new Timer(3000);
    captureTimer.start();
  }


  // Capture image loop (FSM).
  void captureLoop() {
    if (capturePhase == CAPTURE_FLASH)
    {
      background(FLASH_COLOR);
//      background(lerpColor(PROJECTION_BACKGROUND_COLOR, FLASH_COLOR, captureTimer.progress()));
      delay(10);
      if (cam.available()) {
        cam.read();
        capturePhase = CAPTURE_FLASH_WAIT;
        //captureTimer = new Timer(1000);
        captureTimer.start();
      }
    }
    else if (capturePhase == CAPTURE_FLASH_WAIT) {
      background(FLASH_COLOR);
      if (captureTimer.isFinished())
        capturePhase = CAPTURE_SNAPSHOT;
    }
    else if (capturePhase == CAPTURE_SNAPSHOT) {
      background(FLASH_COLOR);
      snapshot(!baseImageRecorded);
      capturePhase = CAPTURE_SNAPSHOT_WAIT; // will wait for response
//      captureTimer = new Timer(1000);
      captureTimer.start();
    }
    else { // CAPTURE_SNAPSHOT_WAIT
      if (!captureTimer.isFinished())
        background(FLASH_COLOR);
//        background(lerpColor(FLASH_COLOR, PROJECTION_BACKGROUND_COLOR, captureTimer.progress()));
      else {
        background(PROJECTION_BACKGROUND_COLOR);
        capturePhase = CAPTURE_DONE;
        // Stop request.
        snapshotRequested = false;
      }
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
    
    // Launch new experiment.
    else if (key == 'n') {
      newExperiment();
    }
  }

  // Launch new experiment.
  void newExperiment() {
    // Reset experiment.
    experiment = new Experiment();
    experiment.start(baseImage);
    
    // Take a first snapshot.
    exposureTimer = new Timer(settings.exposureTimeMs());
    requestSnapshot();
    exposureTimer.start();
    
    nExperiments++;
  }

  // Take a snapshot of reference image with the camera.
  void requestSnapshot() {
    println("Snapshot requested");
    snapshotRequested = true;
//    snapshotTimer.start();
    startCaptureLoop();
  }

  // Called when receiving OSC message.
  void nextImage(String imagePath) {
    glyph = loadImage(imagePath);
    snapshotRequested = false;
  }
  
  // Called when generative script has responded to handshake.
  void ready() {
    if (!neuronsReady) {
      // Launch new experiment.
      newExperiment();
      nExperiments = 0;
      neuronsReady = true;
    }
  }

  // Saves snapshot to disk and sends OSC message to announce
  // creation of new image.
  void snapshot(boolean baseImageSnapshot) {
    background(FLASH_COLOR);
    while (cam.available())
      cam.read();
    
    if (baseImageSnapshot) {
      // Record snapshot.
      baseImage = cam.getImage();
      baseImage.save(savePath("test_base_image.png"));
    }
    else {
      experiment.recordSnapshot(cam.getImage());
    }
  }
}
