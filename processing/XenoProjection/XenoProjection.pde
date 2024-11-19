import oscP5.*;
import netP5.*;

// Constants.
final int OSC_RECEIVE_PORT = 7001;
final int OSC_SEND_PORT = 7002; // sonoscope
final int VIGNETTE_SIDE = 480;

// Globals.
String DATA_DIR;

OscP5 oscP5;
NetAddress sonoscope;

PImage DEFAULT_MASK;

DataManager manager = new DataManager();
SceneManager scenes = new SceneManager();

ExperimentData currentExperiment;
ExperimentData previousExperiment;

ArrayList<Scene> currentExperimentScenes = new ArrayList<Scene>();
ArrayList<Scene> previousExperimentScenes = new ArrayList<Scene>();

SequentialScene sequentialScene;
SequentialScene nextSequentialScene; // sequential scene that will be loaded next
Scene recentGlyphsScene;

float midpointY = 0;//-0.15;
float sequentialSceneRelativeWidth = 0.99;

boolean initialState = true;

/////////////////////////////////////
void setup() {
  fullScreen(P2D);

  smooth();
  noCursor();

  // Init data directory.
  DATA_DIR =  sketchPath("") + "contents/";

  // Create default mask.
  DEFAULT_MASK = createVignetteMask(0);

  // Setup OSC.
  oscP5 = new OscP5(this, OSC_RECEIVE_PORT);

  oscP5.plug(this, "experimentNew", "/xeno/server/new");
  oscP5.plug(this, "experimentStep", "/xeno/server/step");
  oscP5.plug(this, "experimentEnd", "/xeno/server/end");

  sonoscope = new NetAddress("127.0.0.1", OSC_SEND_PORT);

  // Create vignette rectangles.
  Rect singleVignetteRect = createRect(0, midpointY, 1, 0.53);
  Rect doubleVignetteRect = createRect(0, midpointY, 1, 0.4);
  Rect gridVignetteRect   = createRect(0, midpointY, 1, 0.8);

  // Load starting experiments.
  ExperimentData[] allExperiments = loadExperiments(sketchPath("") + "contents/experiments.txt");
  previousExperiment = allExperiments[0].copy();

  // Create first experiment.
  currentExperiment = new ExperimentData("2022-10-13_14:53:52_hexagram-uqam-2022_nodepi-02");

  // Single artificial image of current experiment (image on apparatus).
  if (true)
  {
    Scene scene = new Scene(1, 1, singleVignetteRect);
    GlyphVignette v = new GlyphVignette(currentExperiment);
    v.setArtificialPalette(ArtificialPalette.MAGENTA);
    v.setDataType(DataType.ARTIFICIAL);
    scene.putVignette(0, v);
    scenes.add(scene);
    currentExperimentScenes.add(scene);
  }

  // Side-by-side animation of current experiment.
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

  // Single animation of alternating images from current experiment.
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

  // Stepwise alternating sequence of images from current experiment.
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
  if (scenes.currentScene().isFinished()) {

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
}

void refreshScenes(ArrayList<Scene> scenesToRefresh) {
  for (Scene s : scenesToRefresh)
    s.requestRefresh();
}

boolean newExperimentStarted = false;
void experimentNew(String uid) {
  println("NEW experiment " + uid); //<>//
  if (initialState) {
    experimentEnd(currentExperiment.getUid());
    initialState = false;
  }
  newExperimentStarted = true;
}

void experimentStep(String uid) {
  println("STEP experiment " + uid);
  // First step: update currentExperiment with new UID.
  if (newExperimentStarted) { //<>//
    currentExperiment.reload(uid);
    newExperimentStarted = false;
  }

  // Refresh current experiment.
  currentExperiment.refresh();
  refreshScenes(currentExperimentScenes);
}

void experimentEnd(String uid) {
  try {
  previousExperiment.reload(currentExperiment.getUid());

  refreshScenes(previousExperimentScenes);
  sequentialScene.requestRefresh();

  nextSequentialScene = createSequentialScene(previousExperiment);
  for (int i=0; i<previousExperiment.nImages()-1; i++) {
    GlyphVignette v = new GlyphVignette(previousExperiment);
    v.setIndex(i);
    v.noBorder();
    nextSequentialScene.putVignette(i, v);
  }

  recentGlyphsScene.requestRefresh();
  } catch (Exception e) {
    e.printStackTrace();
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
