import oscP5.*;
import netP5.*;

// Constants.
final int OSC_RECEIVE_PORT = 7001;
final int OSC_SEND_PORT = 7002; // sonoscope
final int VIGNETTE_SIDE = 480;
final String ACTIVATION_VECTOR = "max"; // which code signature vector to send to sonoscope: "min", "max", or "avg"

final float TITLES_FONT_SIZE_PROPORTION = 0.075;

// Globals.
String DATA_DIR;

OscP5 oscP5;
NetAddress sonoscope;

PImage DEFAULT_MASK;
PImage CIRCLE_CLIP_MASK;  // hard black outside circle, transparent inside — clips square corners

DataManager manager = new DataManager();
SceneManager scenes = new SceneManager();

ExperimentData currentExperiment;
ExperimentData previousExperiment;

ArrayList<Scene> currentExperimentScenes = new ArrayList<Scene>();
ArrayList<Scene> previousExperimentScenes = new ArrayList<Scene>();

Scene singleGlyphScene;
SequentialScene sequentialScene;
SequentialScene nextSequentialScene; // sequential scene that will be loaded next
Scene recentGlyphsScene;
Scene pipelineScene;

float midpointY = 0;//-0.15;
float sequentialSceneRelativeWidth = 0.99;

boolean initialState = true;
boolean debugMode = false;

int lastExperimentVisibilityClass = 0;

String overlayMessage = null;
boolean overlayFadingOut = false;
Timer overlayFadeTimer   = new Timer(1000);  // fade-in / fade-out duration
Timer overlayAutoHideTimer = new Timer(15000); // auto-dismiss: fade_in(1s) + hold(5s)
PFont overlayFont;

/////////////////////////////////////
void setup() {
  fullScreen(P2D);

  smooth();
  noCursor();

  // Load font for overlay text (required for P2D renderer).
  overlayFont = createFont("Saira-Regular.ttf", height * 0.25f);

  // Init data directory.
  DATA_DIR =  sketchPath("") + "contents/";

  // Create masks.
  DEFAULT_MASK      = createVignetteMask(0);
  CIRCLE_CLIP_MASK  = createVignetteMask(color(0), 1.0);  // no gradient, just clips to circle

  // Initialise per-stage vignette display styles.
  initVignetteStyles();

  // Setup OSC.
  oscP5 = new OscP5(this, OSC_RECEIVE_PORT);

  oscP5.plug(this, "experimentNew",   "/xeno/server/new");
  oscP5.plug(this, "experimentBegin", "/xeno/server/begin");
  oscP5.plug(this, "experimentStep",  "/xeno/server/step");
  oscP5.plug(this, "experimentEnd",               "/xeno/server/end");
  oscP5.plug(this, "experimentEndWithVisibility", "/xeno/server/end");

  oscP5.plug(this, "snapshot",  "/xeno/server/snapshot");

  sonoscope = new NetAddress("127.0.0.1", OSC_SEND_PORT);

  // Create vignette rectangles.
  Rect singleVignetteRect = createRect(0, midpointY, 1, 0.53);
  Rect doubleVignetteRect = createRect(0, midpointY, 1, 0.4);
  Rect gridVignetteRect   = createRect(0, midpointY, 1, 0.8);

  // Load starting experiments.
  ExperimentData[] allExperiments = loadExperiments(sketchPath("") + "contents/experiments.txt");
  previousExperiment = new ExperimentData("2025-12-17_12:26:33_xpanse-2024_nodepi-01");
  currentExperiment  = previousExperiment.copy();

  // Single artificial image of current experiment (image on apparatus).
  if (true)
  {
    Scene scene = new Scene(1, 1, singleVignetteRect);
    scene.setOscAddress("/xeno/sonoscope/activations");
    GlyphVignette v = new GlyphVignette(currentExperiment);
    v.setArtificialPalette(ArtificialPalette.MAGENTA);
    v.setDataType(DataType.ARTIFICIAL);
    scene.putVignette(0, v);
    scenes.add(scene);
    currentExperimentScenes.add(scene);
    singleGlyphScene = scene;
  }

  // Side-by-side animation of last experiment.
  if (true)
  {
    Scene scene = new Scene(2, 1, doubleVignetteRect);

    MorphoVignette v;

    v= new MorphoVignette(previousExperiment);
    v.setArtificialPalette(ArtificialPalette.WHITE);
    v.setDataType(DataType.ARTIFICIAL);
    scene.putVignette(0, v);

    v= new MorphoVignette(previousExperiment);
    v.setDataType(DataType.BIOLOGICAL);
    scene.putVignette(1, v);

    scenes.add(scene);
    previousExperimentScenes.add(scene);
  }

  // Single animation of alternating images from last experiment.
  if (true)
  {
    Scene scene = new Scene(1, 1, singleVignetteRect);
    scene.setOscAddress("/retina");

    MorphoVignette v;

    v= new MorphoVignette(previousExperiment);
    scene.setOscAddress("/retina");
    v.setArtificialPalette(ArtificialPalette.MAGENTA);
    v.setDataType(DataType.ALL);
    v.setLastImageOffset(1);
    v.setUseInterpolation(true);
    scene.putVignette(0, v);
    scenes.add(scene);
    previousExperimentScenes.add(scene);    
  }

  // Stepwise alternating sequence of images from last experiment.
  if (true)
  {
    SequentialScene scene = createSequentialScene(previousExperiment);
    scene.setOscAddress("/sequence");
    for (int i=0; i<previousExperiment.nImages()-1; i++) {
      GlyphVignette v = new GlyphVignette(previousExperiment);
      v.setIndex(i);
      v.noBorder();
      scene.putVignette(i, v);
    }
    scenes.add(scene);
    sequentialScene = nextSequentialScene = scene;
  }

  // Animation of recent generative glyphs.
  if (true)
  {
    Scene scene = new Scene(5, 2, gridVignetteRect);
    for (int i=0; i<min(scene.nVignettes(), allExperiments.length); i++) {
      MorphoVignette v = new MorphoVignette(allExperiments[i]);
      v.setDataType(DataType.BIOLOGICAL);
      scene.putVignette(i, v);
    }
    scenes.add(scene);
    recentGlyphsScene = scene;
  }

  // CV pipeline scene: all stages from color source to final output (3 cols × 2 rows).
  // Row 0: col (color source), bsb (color−base), 0trn (transform)
  // Row 1: 1fil (enhance), 3ann (raw AE output), 4prj (postprocessed → projected)
  if (true)
  {
    Scene scene = new Scene(3, 2, gridVignetteRect);
    String[] stages = {"col", "bsb", "0trn", "1fil", "3ann", "4prj"};
    for (int i = 0; i < stages.length; i++) {
      PipelineVignette v = new PipelineVignette(currentExperiment, stages[i]);
      if (stages[i].equals("4prj"))
        v.setArtificialPalette(ArtificialPalette.MAGENTA);
      scene.putVignette(i, v);
    }
    scene.setSequential(true);
    scenes.add(scene);
    pipelineScene = scene;
    currentExperimentScenes.add(scene);
  }

  // Build all scenes.
  for (Scene s : scenes) {
    s.build();
  }
  
  // Start first scene.
  scenes.currentScene().start();
}


////////////////////////////////////////////////////
void draw() {
  // Clear background.
  // Clear background.
  background(0);
  
  // If current scene has ended, cleanup and go to next scene.
  if (scenes.currentScene().isFinished() && scenes.hasEnabledScene()) {

    // Make sure all scenes are built properly.
    for (int i=0; i<scenes.size(); i++) {

      Scene s = scenes.get(i);
      if (s.needsRefresh()) {
        // Deal with special cases.
        if (s == sequentialScene) {
          sequentialScene = nextSequentialScene;
          scenes.set(i, sequentialScene);
          s = sequentialScene;
        } else if (s == recentGlyphsScene) {
          MorphoVignette v = new MorphoVignette(previousExperiment.copy());
          v.setDataType(DataType.BIOLOGICAL);
          s.insertVignette(0, v);
        }

        // Build scene.
        s.build();
      }
    }

    // Switch to next scene.
    scenes.nextScene();
  }

  // Display current scene.
  scenes.currentScene().display();

  // Overlay: fade scene to black and show message.
  if (overlayMessage != null) {
    float p = overlayFadingOut
      ? 1.0 - overlayFadeTimer.progress()
      : overlayFadeTimer.progress();
    float maskOpacity = p * 255;

    noStroke();
    fill(0, maskOpacity);
    rect(width/2, height/2, width, height);

    fill(255, maskOpacity);
    textFont(overlayFont);
    textAlign(CENTER, CENTER);
    textSize(height * TITLES_FONT_SIZE_PROPORTION);
    text(overlayMessage, width/2, height/2);

    // Auto-hide after hold duration if no explicit hideOverlay() was called.
    if (!overlayFadingOut && overlayAutoHideTimer.isFinished())
      hideOverlay();

    // Once fade-out completes, clear the overlay.
    if (overlayFadingOut && overlayFadeTimer.isFinished()) {
      overlayMessage = null;
      overlayFadingOut = false;
    }
  }
}

void refreshScenes(ArrayList<Scene> scenesToRefresh) {
  for (Scene s : scenesToRefresh)
    s.requestRefresh();
} 

boolean newExperimentStarted = false;
void experimentNew(String uid) {
  println("NEW experiment " + uid);
  newExperimentStarted = true;
}

void experimentBegin() {
  println("BEGIN experiment");
  showOverlay("MESOSCOPE\nUNE NOUVELLE EXPÉRIENCE DÉBUTE\nNEW EXPERIMENT STARTING");
}

void experimentStep(String uid) {
  println("STEP experiment " + uid);
  // First step: update currentExperiment with new UID.
  if (newExperimentStarted) { 
    if (initialState) {
      experimentEnd(currentExperiment.getUid());
      initialState = false;
    }
    
    currentExperiment.reload(uid); 
    newExperimentStarted = false;
  }

  // Refresh current experiment.
  currentExperiment.refresh();
  refreshScenes(currentExperimentScenes);

  // Only show the pipeline scene when pre-AE images exist (not on the first
  // randomly-seeded step, which only produces 3ann + 4prj).
  if (pipelineScene != null)
    pipelineScene.setEnabled(!currentExperiment.listPipelineFiles("1fil").isEmpty());

  // Load latest encoder activations so they are sent when scene 0 starts.
  if (singleGlyphScene != null)
    singleGlyphScene.setActivations(currentExperiment.getLatestActivations(ACTIVATION_VECTOR));

  // Go to first scene.
  hideOverlay();
  scenes.setCurrentScene(0);
  scenes.currentScene().build();
}

// Called when experiment ends AND visibility class is known (new message format).
void experimentEndWithVisibility(String uid, int visClass) {
  lastExperimentVisibilityClass = visClass;
  experimentEnd(uid);
}

void experimentEnd(String uid) {
  try {
    previousExperiment.reload(uid);

    refreshScenes(previousExperimentScenes);
    sequentialScene.requestRefresh();

    nextSequentialScene = createSequentialScene(previousExperiment);
    for (int i=0; i<previousExperiment.nImages()-1; i++) {
      GlyphVignette v = new GlyphVignette(previousExperiment);
      v.setIndex(i);
      v.noBorder();
      nextSequentialScene.putVignette(i, v);
    }

    // Only add to recent glyphs if the glyph was human-visible.
    if (lastExperimentVisibilityClass >= 2) {
      recentGlyphsScene.requestRefresh();
    }
    // Reset for next experiment.
    lastExperimentVisibilityClass = 0;
  } catch (Exception e) {
    e.printStackTrace();
  }
}

void snapshot() {
  showOverlay("MESOSCOPE\nUN NOUVEAU GLYPHE ÉMERGE\nA NEW GLYPH EMERGES");
}

void showOverlay(String message) {
  overlayMessage = message;
  overlayFadingOut = false;
  overlayFadeTimer.start();
  overlayAutoHideTimer.start();
}

void hideOverlay() {
  if (overlayMessage != null && !overlayFadingOut) {
    overlayFadingOut = true;
    overlayFadeTimer.start();
  }
}

SequentialScene createSequentialScene(ExperimentData exp) {
  return new SequentialScene( exp.nImages()-1, 50, createRect(0, midpointY, sequentialSceneRelativeWidth, 1));
}

////////////////////////////////////////////////////
void keyPressed() {
  if (key == 's')
    saveFrame();
  else if (key == 'o')
    sendOSCMessage("/example", random(10));
  else if (key == 'd') {
    debugMode = !debugMode;
    for (Scene s : scenes) s.setDebug(debugMode);
    println("Debug mode: " + debugMode);
  }
  else if (key == 'n') {
    for (Scene s : scenes) s.setEnabled(false);
    println("All scenes disabled.");
  }
  else if (key == 'a') {
    for (Scene s : scenes) s.setEnabled(true);
    println("All scenes enabled.");
  }
  else if (key >= '1' && key <= '6') {
    int idx = key - '1';
    if (idx < scenes.size()) {
      Scene s = scenes.get(idx);
      s.setEnabled(!s.isEnabled());
      println("Scene " + (idx+1) + ": " + (s.isEnabled() ? "enabled" : "disabled"));
    }
  }
}

////////////////////////////////////////////////////
// This function is automatically called when an OSC message is received
void oscEvent(OscMessage message) {
  // Print the address pattern of the message
  println("Received OSC message: " + message.addrPattern());
}


////////////////////////////////////////////////////
// Function to send an OSC message
void sendOSCMessage(String address, float value) {
  // Create a new OSC message with a specific address pattern
  OscMessage message = new OscMessage(address);
  
  // Add arguments to the message
  message.add(value); // Add a float argument, for example
  
  // Send the OSC message to the destination
  oscP5.send(message, sonoscope);
  
  println("Sent OSC message: " + address + " with value " + value);
}
