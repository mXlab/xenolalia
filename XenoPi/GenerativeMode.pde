// Capture FSM state enum.
enum State {
  INIT, 
  NEW, 
  MAIN, 
  FLASH, 
  SNAPSHOT, 
  WAIT_FOR_GLYPH
}

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

  // Snapshot-related.
  Timer exposureTimer;
  Timer stateTimer;

  final int FLASH_TIME = 6000;

  State state;

  // Experiment manager.
  Experiment experiment; // current experiment
  int nExperiments;

  // Current base image.
  PImage baseImage;

  boolean neuronsReady;
  boolean newExperimentStarted;
  boolean snapshotRequested;
  boolean newExperimentRequested;
  boolean nextGlyphReceived;

  boolean newState; // true when entering a new state

  void setup() {
    transitionTo(State.INIT);
  }

  void draw() {
    // Remove annoying cursor.
    noCursor();

    // State machine.

    // INIT : Initialize everything upon entering generative mode and wait for xeno_osc.py to be ready.
    if (state == State.INIT) {
      background(255, 0, 0);
      
      // Initialize everything.
      if (enteredState()) {
        neuronsReady = false;
        newExperimentStarted = false;
        nExperiments = -1;

        // Send first handshake.
        oscP5.send(new OscMessage("/xeno/euglenas/handshake"), remoteLocation);

        stateTimer = new Timer(100);
        stateTimer.start();

        exposureTimer = new Timer(settings.exposureTimeMs());
      }

      // Send handshakes and wait for response.
      if (!neuronsReady) {
        background(0);
        fill(255);
        textSize(32);
        text("Waiting for xeno_osc.py response", 10, height-10);

        // Send handshake message regularly.
        if (stateTimer.isFinished()) {
          // Send handshake.
          oscP5.send(new OscMessage("/xeno/euglenas/handshake"), remoteLocation);
          stateTimer.start();
        }
      }
      
      // Neurons are ready: start new experiment!
      else {
        transitionTo(State.NEW);
      }
    }

    // NEW experiment : Create new experiment and run a first capture loop to get base image.
    else if (state == State.NEW) {
      background(0, 255, 0);
      // Reset experiment.
      experiment = new Experiment();
      nExperiments++;

      // First snapshot will be base image.
      newExperimentStarted = false;

      // Flash.
      transitionTo(State.FLASH);
    }

    // FLASH : Set white background 
    else if (state == State.FLASH) {
     
      if (enteredState()) {
        // Start timer.
        stateTimer = new Timer(FLASH_TIME);
        stateTimer.start();
      }
      
      // Set color to flash.
      background(FLASH_COLOR);

      // Keep on emptying camera buffer.
      if (cam.available())
        cam.read();

      // When finished: transit to snapshot mode.
      if (stateTimer.isFinished()) {
        transitionTo(State.SNAPSHOT);
      }
    }

    // SNAPSHOT : Take a picture.
    else if (state == State.SNAPSHOT) {
      // Wait until a new image is available before taking accepting the snapshot.
      if (cam.available()) {
        cam.read(); // this image should be ok

        if (newExperimentStarted) {
          // Reset next glyph received flag.
          nextGlyphReceived = false;
          
          // Take a snapshot.
          snapshot(false);

          // Wait for glyph.
          transitionTo(State.WAIT_FOR_GLYPH);
        }
        
        else {
          // Take shot of base image.
          snapshot(true);
          
          // Go directly to MAIN.
          transitionTo(State.MAIN);
        }
      }
    }

    // WAIT_FOR_GLYPH : Wait for response from server to get glyph.
    else if (state == State.WAIT_FOR_GLYPH) {
      if (nextGlyphReceived)
        transitionTo(State.MAIN);
    }

    // MAIN loop : Display glyph and oher shit.
    else if (state == State.MAIN) {
      if (enteredState()) {
        // If we got here right after a new experiment was done, we can now start the experiment since we have the base image.
        if (!newExperimentStarted) {
          println("Start new experiment");
          experiment.start(baseImage);
          newExperimentStarted = true;
          transitionTo(State.FLASH);
          return; // exit
        }

        // Start exposure timer.
        exposureTimer.start();
      }

      // Capture video.
      if (cam.available())
        cam.read();

      // Display background or projected image depending on flash status.
      if (flash) { // flash!
        background(FLASH_COLOR);
      } else { // projected image
        println("Project image");
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

      // In auto-mode: collect snapshots at a regular pace.
      if (autoMode && exposureTimer.isFinished()) {
        println("Auto trigger");
        requestSnapshot();
      }
      
      if (newExperimentRequested) {
        transitionTo(State.NEW);
        newExperimentRequested = false;
      }
      else if (snapshotRequested) {
        println("Snap req.");
        transitionTo(State.FLASH);
      }
    }
  }

  void transitionTo(State nextState) {
    state = nextState;
    newState = true;
    println("Switching to state: " + nextState);
    println("   t = " + millis());
    if (stateTimer != null)
      println("   timer = " + stateTimer.passedTime());
  }

  boolean enteredState() {
    boolean isEntering = newState;
    newState = false;
    return isEntering;
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
      requestNewExperiment();
    }
  }

  void requestNewExperiment() {
    newExperimentRequested = true;
  }

  // Take a snapshot of reference image with the camera.
  void requestSnapshot() {
    snapshotRequested = true;
  }

  // Called when receiving OSC message.
  void nextImage(String imagePath) {
    println("Received image: " + imagePath, nextGlyphReceived);
    glyph = loadImage(imagePath);
    snapshotRequested = false;
    nextGlyphReceived = true;
  }

  // Saves snapshot to disk and sends OSC message to announce
  // creation of new image.
  void snapshot(boolean baseImageSnapshot) {
    if (baseImageSnapshot) {
      // Record snapshot.
      baseImage = cam.getImage();
      baseImage.save(savePath("test_base_image.png"));
    }
    else
      experiment.recordSnapshot(cam.getImage());
  }

  // Called when generative script has responded to handshake.
  void ready() {
    neuronsReady = true;
  }
}
