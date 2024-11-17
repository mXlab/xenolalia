import oscP5.*;
import netP5.*;


OscP5 oscP5;

//final String DATA_DIR = "/home/sofian/Desktop/xenolalia/contents/";
//final String DATA_DIR = "/Users/tez/Projects/XENOSOUND/XenoProjection/contents/";

String DATA_DIR; 

final int VIGNETTE_SIDE = 480;

final int OSC_RECEIVE_PORT = 7001;
final int OSC_SEND_PORT = 7002; // sonoscope

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

NetAddress sonoscope;

float midpointY = -0.15;

/////////////////////////////////////
void setup() {
    //size(1920, 1080, P2D);
    //size(1280, 720, P2D);
  fullScreen(P2D);

  DATA_DIR =  sketchPath("") + "contents/";

  smooth();
  DEFAULT_MASK = createVignetteMask(0);

  // Setup OSC.
  oscP5 = new OscP5(this, OSC_RECEIVE_PORT);

  oscP5.plug(this, "experimentNew", "/xeno/server/new");
  oscP5.plug(this, "experimentStep", "/xeno/server/step");
  oscP5.plug(this, "experimentEnd", "/xeno/server/end");

  sonoscope = new NetAddress("127.0.0.1", OSC_SEND_PORT);

  Rect singleVignetteRect = createRect(0, midpointY, 1, 0.53);
  Rect doubleVignetteRect = createRect(0, midpointY, 1, 0.4);
  Rect gridVignetteRect   = createRect(0, midpointY, 1, 0.4);

  // Create first scene.
  currentExperiment = new ExperimentData("2022-10-13_14:53:52_hexagram-uqam-2022_nodepi-02");

  ExperimentData[] allExperiments = loadExperiments(sketchPath("") + "contents/experiments.txt");

  ExperimentData[] allExperiments = loadExperiments(sketchPath("") + "contents/experiments.txt");

  previousExperiment = allExperiments[0];

  // Single artificial image of current experiment (image on apparatus).
  if (false)
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
  if (false)
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
    
    zerosequences();
    sequences[1]=1;
    
  }

  // Stepwise alternating sequence of images from current experiment.
  if (true)
  {
    SequentialScene scene = createSequentialScene(previousExperiment);
    scene.setOscAddress("/sequence");
    scene.oscSendMessage("/test", 0);
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
  if (false)
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

  for (Scene s : scenes) {
    s.build();
  }
  
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
  println("NEW experiment " + uid);
  newExperimentStarted = true;
}

void experimentStep(String uid) {
  println("STEP experiment " + uid);
  // First step: update currentExperiment with new UID.
  if (newExperimentStarted) {
    currentExperiment.reload(uid);
    newExperimentStarted = false;
  }

  // Refresh current experiment.
  currentExperiment.refresh();
  refreshScenes(currentExperimentScenes);
}

void experimentEnd(String uid) {
  println("END experiment " + uid);
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
}

SequentialScene createSequentialScene(ExperimentData exp) {
  return new SequentialScene( exp.nImages()-1, 50, createRect(0, midpointY, 1, 1));
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
