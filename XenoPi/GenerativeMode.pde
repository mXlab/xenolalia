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

  void setup() {
    // Launch new experiment.
    newExperiment();
    nExperiments = 0;
  }

  ///////////////////////////////////////
  void draw() {

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
      String status = "exp # " + nExperiments + "  ";
      if (autoMode)
        status += "auto mode: " + nf(exposureTimer.countdownTime()/1000.0f, 3, 1) + " s";
      else
        status += "manual mode";
      text(status, 10, height-10);
    }
  }

  void startCaptureLoop() {
    capturePhase = CAPTURE_FLASH;
    captureTimer = new Timer(1000);
    captureTimer.start();
  }


  // Capture image loop (FSM).
  void captureLoop() { //<>//
    if (capturePhase == CAPTURE_FLASH) //<>//
    {
      if (!captureTimer.isFinished()) {
        background(lerpColor(PROJECTION_BACKGROUND_COLOR, FLASH_COLOR, captureTimer.progress()));
      } else {
        background(FLASH_COLOR);
        delay(10);
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
      snapshot();
      capturePhase = CAPTURE_SNAPSHOT_WAIT; // will wait for response
//      captureTimer = new Timer(1000);
      captureTimer.start();
    }
    else { // CAPTURE_SNAPSHOT_WAIT
      if (!captureTimer.isFinished())      
        background(lerpColor(FLASH_COLOR, PROJECTION_BACKGROUND_COLOR, captureTimer.progress()));
      else {
        background(PROJECTION_BACKGROUND_COLOR);
        capturePhase = CAPTURE_DONE;
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
    experiment.start();
    
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
    img = loadImage(imagePath);
    snapshotRequested = false;
  }

  // Saves snapshot to disk and sends OSC message to announce
  // creation of new image.
  void snapshot() {
    // Record snapshot.
    experiment.recordSnapshot(cam.getImage());
  }
}
