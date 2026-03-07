// Capture FSM state enum.
enum State {
    INIT,
    NEW,
    REFRESH,
    POST_REFRESH,
    MAIN,
    FLASH,
    SNAPSHOT,
    WAIT_FOR_GLYPH,
    PRESENTATION,
    IDLE
}

// This mode runs the generative process through interoperability
// with python script.
class GenerativeMode extends AbstractMode {

  // The "glyph" image currently displayed in background.
  PImage glyph;

  // Filtered image shown briefly as overlay after receiving a new glyph.
  PImage filterOverlay;
  int overlayStartTime = -1;
  final int OVERLAY_DURATION = 5000;

  // Status flags.
  boolean flash = false;
  boolean camView = false;
  boolean autoMode = true;
  boolean displayHelp = false;

  // Corner cam dimensions.
  final int CAM_VIEW_WIDTH = 200;
  final int CAM_VIEW_HEIGHT = 200;

  // Base colors.
  final color FLASH_COLOR = color(255);
//  final color POST_REFRESH_COLOR = color(#00ffff); // cyan
  final color POST_REFRESH_COLOR = color(#7efeff); // blue-cyan
  final color PROJECTION_COLOR = color(#ff00ff); // magenta
  final color PROJECTION_BACKGROUND_COLOR = color(0);

  // Snapshot-related.
  Timer exposureTimer;
  Timer stateTimer;
  Timer cameraWatchdogTimer;

  final int FLASH_TIME = 8000;
  final int GLOW_STOP_BEFORE_SNAPSHOT_TIME = 3000; // should be smaller than FLASH_TIME
  final int HANDSHAKE_TIMEOUT = 5000;
  final int SNAPSHOT_BASE_TIME = 10000;
  final int SNAPSHOT_INTER_SHOT_TIME = 2000;
  final int SNAPSHOT_CAMERA_TIMEOUT = 60000; // restart camera if no frame within this time
  
  final int N_SNAPSHOTS_PER_EXPERIMENT = 12;
  //final int N_SNAPSHOTS_PER_EXPERIMENT = 3;
  
  // Time to wait for liquid to settle after refresh.
  final int POST_REFRESH_TIME = 120000; // 2 minutes
  
  // At the end of a cycle, wait for this time to present the result.
  final int PRESENTATION_TIME = 300000; // 5 minutes

  State state;

  // Experiment manager.
  Experiment experiment; // current experiment
  int nExperiments;

  // Current base image.
  PImage baseImage;

  // Current snapshot.
  PImage snapshot;

  boolean neuronsReady;
  boolean apparatusRefreshed;
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
        snapshot = null;
        neuronsReady = false;
        apparatusRefreshed = false;
        newExperimentStarted = false;
        nExperiments = -1;

        // Send first handshake.
        oscP5.send(new OscMessage("/xeno/euglenas/handshake"), remoteLocation);

        stateTimer = new Timer(100);
        stateTimer.start();

        exposureTimer = new Timer(settings.exposureTimeMs());

        setRingStyle(RING_DARK);
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

      // Flash or refresh.
      if (settings.useApparatus())
        transitionTo(State.REFRESH);
      else
        transitionTo(State.FLASH);
    }

    // SHAKE: Shake the liquid in apparatus.
    else if (state == State.REFRESH) {
      background(255, 0, 255);
      if (enteredState()) {
        // Start timer.
        stateTimer = new Timer(HANDSHAKE_TIMEOUT);
        stateTimer.start();

        apparatusRefreshed = false;

        // Ask apparatus to shake.
        refresh();
      }

      if (!apparatusMessageReceived && stateTimer.isFinished()) {
        background(50);
        // Ask apparatus to shake again.
        log("Try to refresh again");
        //refresh();
        stateTimer.start();
      }

      if (apparatusRefreshed) {
        // Post-refresh.
        transitionTo(State.POST_REFRESH);
      }
    }

    // POST_REFRESH : Wait for euglenas to settle in petri dish.
    else if (state == State.POST_REFRESH) {
      background(POST_REFRESH_COLOR);
      if (enteredState()) {
        // Start timer.
        stateTimer = new Timer(POST_REFRESH_TIME);
        stateTimer.start();
      }

      if (stateTimer.isFinished()) {
        // Flash.
        transitionTo(State.FLASH);
      }

    }

    // FLASH : Set white background 
    else if (state == State.FLASH) {

      if (enteredState()) {
        // Start timer.
        stateTimer = new Timer(FLASH_TIME);
        stateTimer.start();
        setRingStyle(RING_GLOW);
      }

      // Set color to flash.
      background(FLASH_COLOR);

      // Keep on emptying camera buffer.
      if (cam.available())
        cam.read();

      // Stop glow early to prevent it from affecting snapshots.
      if (stateTimer.countdownTime() <= GLOW_STOP_BEFORE_SNAPSHOT_TIME) {
        setRingStyle(RING_DARK);
      }

      // When finished: transit to snapshot mode.
      if (stateTimer.isFinished()) {
        setRingStyle(RING_DARK);
        transitionTo(State.SNAPSHOT);
      }
    }

    // SNAPSHOT : Take a picture.
    else if (state == State.SNAPSHOT) {
      // Wait until a new image is available before taking accepting the snapshot.
      if (enteredState()) {
        snapshot = null;
        stateTimer = new Timer(SNAPSHOT_BASE_TIME);
        stateTimer.start();
        cameraWatchdogTimer = new Timer(SNAPSHOT_CAMERA_TIMEOUT);
        cameraWatchdogTimer.start();
      }

      // Set color to flash.
      background(FLASH_COLOR);

      // Attempt to take a snapshot, discarding images containing lines artifacts.
      if (cam.available()) {
        cam.read();
        if (stateTimer.isFinished()) {
          println("Trying to take snapshot.");
          PImage img = cam.getImage();
          // If no lines detected, save image.
          if (!imageLineDetected(img)) {
            snapshot = img;
          }
          // Otherwise save image to disk and retry.
          else {
            float confidence = imageLineDetectConfidence(img);
            println("Detected line with confidence: " + confidence);
            img.save(savePath(experiment.experimentDir() + "/lined_image_" + millis() + "_" + confidence + ".png"));
            stateTimer.setTotalTime(SNAPSHOT_INTER_SHOT_TIME);
            stateTimer.start();
          }
        }
      }

      // Camera watchdog: if no frame received for too long (or camera flagged an error),
      // exit and let the run_sketch.sh restart loop relaunch cleanly.
      // In-place GLCapture reinitialize corrupts Processing's shared GL context,
      // so a full restart is the only safe recovery path.
      if (snapshot == null && (cameraWatchdogTimer.isFinished() || (cam instanceof GLCaptureCam && ((GLCaptureCam)cam).isError))) {
        println("Camera watchdog triggered: restarting sketch.");
        exit();
      }

      // Process snapshot.
      if (snapshot != null) {
        println("Snapshot taken without lines");
        if (newExperimentStarted) {
          // Reset next glyph received flag.
          nextGlyphReceived = false;

          // Take a snapshot.
          snapshot(false);

          // Wait for glyph.
          transitionTo(State.WAIT_FOR_GLYPH);
        } else {
          // Take shot of base image.
          snapshot(true);

          // Go directly to MAIN.
          transitionTo(State.MAIN);
        }
      }
    }

    // WAIT_FOR_GLYPH : Wait for response from server to get glyph.
    else if (state == State.WAIT_FOR_GLYPH) {
      if (enteredState()) // this is just to print a message
      {} // nothing to do here
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

        // Turn on idle light while projecting glyph.
        setRingStyle(RING_IDLE);
      }

      // Capture video.
      if (cam.available())
        cam.read();

      // Display background or projected image depending on flash status.
      if (flash) { // flash!
        background(FLASH_COLOR);
      } else { // projected image
        background(PROJECTION_BACKGROUND_COLOR);
        tint(PROJECTION_COLOR); // tint
        drawScaledImage(glyph);
        // Briefly overlay the CV-detected shape.
        if (filterOverlay != null && overlayStartTime >= 0) {
          int elapsed = millis() - overlayStartTime;
          if (elapsed < OVERLAY_DURATION) {
            // Fade out during the last 20% of the duration.
            float progress = (float)elapsed / OVERLAY_DURATION;
            float alpha = (progress > 0.8) ? map(progress, 0.8, 1.0, 200, 0) : 200;
            tint(255, constrain(alpha, 0, 200));
            drawScaledImage(filterOverlay);
            noTint();
          } else {
            overlayStartTime = -1;
            noTint();
          }
        }
      }

      // Camera view in the top-left corner.
      if (camView) {
        noTint();
        imageMode(CORNER);
        image(cam.getImage(), 0, 0, CAM_VIEW_WIDTH, CAM_VIEW_HEIGHT);
      }

      if (displayHelp) {
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

      // In auto-mode: collect snapshots at a regular pace.
      if (autoMode && exposureTimer.isFinished()) {
        
         if (experiment.nSnapshots() < N_SNAPSHOTS_PER_EXPERIMENT)
           requestSnapshot();
         else {
           setRingStyle(RING_DARK);
           transitionTo(State.PRESENTATION);
         }
      }

      if (newExperimentRequested) {
        setRingStyle(RING_DARK);
        transitionTo(State.NEW);
        newExperimentRequested = false;
        experiment.updateServer("end"); // tell server current experiment is over
      } else if (snapshotRequested) {
        println("Snap req.");
        setRingStyle(RING_DARK);
        transitionTo(State.FLASH);
      }
    }
    
    // IDLE : Stopped externally. Black screen. Wait for /xeno/control/begin to restart.
    else if (state == State.IDLE) {
      background(0);
    }

    // PRESENTATION loop : Display flash background to show result.
    else if (state == State.PRESENTATION) {
      if (enteredState()) {
        stateTimer = new Timer(PRESENTATION_TIME);
        stateTimer.start();
        setRingStyle(RING_GLOW);
      }

      background(FLASH_COLOR);

      if (stateTimer.isFinished()) {
        transitionTo(State.NEW);
        newExperimentRequested = false;
        experiment.updateServer("end"); // tell server current experiment is over
        setRingStyle(RING_DARK);
      }

    }
  }

  void transitionTo(State nextState) {
    state = nextState;
    newState = true;
    log("Switching to state: " + nextState);
    log("   t = " + millis());
    if (stateTimer != null)
      log("   timer = " + stateTimer.passedTime());
  }

  boolean enteredState() {
    boolean isEntering = newState;
    if (isEntering) {
      println("Entering state: " + state);
      // Update server.
      OscMessage msg = new OscMessage("/xeno/exp/state");
      msg.add(state.toString());
      oscP5.send(msg, remoteLocationServer);
    }
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
    
    // Toggle display help.
    else if (key == 'h') {
      displayHelp = !displayHelp;
    }

    // Launch new experiment.
    else if (key == 'n') {
      requestNewExperiment();
    }

    // Test overlay: load most recent _3ann.png from snapshots.
    else if (key == 't') {
      String testPath = findMostRecentFile(savePath("snapshots/"), "_3ann.png");
      if (testPath != null) {
        println("Test overlay: " + testPath);
        nextImage(testPath);
      } else {
        println("No _3ann.png found for overlay test.");
      }
    }
  }

  void requestNewExperiment() {
    newExperimentRequested = true;
  }

  // Called when receiving /xeno/control/stop from xeno_server.py.
  // Immediately transitions to IDLE (black screen) regardless of current state.
  // Resume by sending /xeno/control/begin.
  void requestStop() {
    log("Stop received — going to IDLE.");
    setRingStyle(RING_DARK);
    transitionTo(State.IDLE);
  }

  // Take a snapshot of reference image with the camera.
  void requestSnapshot() {
    snapshotRequested = true;
  }

  // Called when receiving OSC visibility message from xeno_osc.py.
  void neuronsVisibility(int visClass) {
    if (experiment != null)
      experiment.updateVisibility(visClass);
  }

  // Called when receiving OSC message.
  void nextImage(String imagePath) {
    println("Received image: " + imagePath, nextGlyphReceived);
    glyph = loadImage(imagePath);
    // Load the filtered (enhanced) image for overlay display.
    String filteredPath = imagePath.replace("_3ann.png", "_1fil.png");
    PImage loaded = loadImage(filteredPath);
    if (loaded != null && loaded.width > 0) {
      filterOverlay = loaded;
      overlayStartTime = millis();
    }
    snapshotRequested = false;
    nextGlyphReceived = true;
    experiment.updateServer("step");
  }

  // Saves snapshot to disk and sends OSC message to announce
  // creation of new image.
  void snapshot(boolean baseImageSnapshot) {
    if (baseImageSnapshot) {
      // Record snapshot.
      baseImage = snapshot;
      baseImage.save(savePath("test_base_image.png"));
    } else {
      experiment.recordSnapshot(snapshot);
//      camFilter.saveImages(experiment);
    }
  }

  // Called when generative script has responded to handshake.
  void ready() {
    neuronsReady = true;
  }

  void refreshed() {
    apparatusRefreshed = true;
  }

  void refresh() {
    apparatusMessageReceived = false;

    // Ask apparatus to shake.
    OscMessage msg = new OscMessage("/xeno/refresh");
    msg.add(1);
    oscP5.send(msg, remoteLocationApparatus);
    
    log("Sent call for refreshing");
  }

  // Ring style constants (must match xenolalia::RingStyle enum order).
  static final int RING_DARK       = 0;
  static final int RING_IDLE       = 1;
  static final int RING_GLOW       = 2;
  static final int RING_ILLUMINATE = 3;

  void setRingStyle(int style) {
    OscMessage msg = new OscMessage("/xeno/ring");
    msg.add(style);
    oscP5.send(msg, remoteLocationApparatus);
    log("Ring style → " + style);
  }

  // Returns the path of the most recent file with the given suffix under dir,
  // searching one level of subdirectories. Returns null if none found.
  String findMostRecentFile(String dir, String suffix) {
    File root = new File(dir);
    if (!root.exists()) return null;
    ArrayList<String> found = new ArrayList<String>();
    // Check direct children and one level of subdirectories.
    File[] dirFiles = root.listFiles();
    if (dirFiles != null) {
      for (File f : dirFiles) {
        if (f.isFile() && f.getName().endsWith(suffix))
          found.add(f.getPath());
        if (f.isDirectory()) {
          File[] subFiles = f.listFiles();
          if (subFiles != null)
            for (File sf : subFiles)
              if (sf.isFile() && sf.getName().endsWith(suffix))
                found.add(sf.getPath());
        }
      }
    }
    if (found.isEmpty()) return null;
    Collections.sort(found);
    return found.get(found.size() - 1);
  }
}
