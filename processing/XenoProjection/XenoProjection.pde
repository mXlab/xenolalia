import oscP5.*; //<>//

OscP5 oscP5;

final String DATA_DIR = "/home/sofian/Desktop/xenolalia/contents/";
final int VIGNETTE_SIDE = 480;

final int OSC_RECEIVE_PORT = 7001;

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

void setup() {
  size(1920, 1080, P2D);
  //fullScreen(P2D);

  smooth();
  DEFAULT_MASK = createVignetteMask(0);

  // Setup OSC.
  oscP5 = new OscP5(this, OSC_RECEIVE_PORT);

  oscP5.plug(this, "experimentNew", "/xeno/server/new");
  oscP5.plug(this, "experimentBegin", "/xeno/server/begin");
  oscP5.plug(this, "experimentStep", "/xeno/server/step");
  oscP5.plug(this, "experimentEnd", "/xeno/server/end");


  // Create first scene.
  currentExperiment = new ExperimentData("2022-10-07_13:53:30_hexagram-uqam-2022_nodepi-02");
  previousExperiment = new ExperimentData("2022-10-07_13:53:30_hexagram-uqam-2022_nodepi-02");
  ExperimentData[] allExperiments = loadExperiments("/home/sofian/Desktop/xenolalia/contents/experiments.txt");

  // Single artificial image of current experiment (image on apparatus).
  if (true)
  {
    Scene scene = new Scene(1, 1, createRect(0, 0.5, 1, 0.5));
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
    Scene scene = new Scene(2, 1);

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
    Scene scene = new Scene(1, 1);

    MorphoVignette v;

    v= new MorphoVignette(previousExperiment);
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
    SequentialScene scene = new SequentialScene(previousExperiment.nImages()-1, 50);
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
    Scene scene = new Scene(5, 2);
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

void draw() {
  background(0);

  Scene current = scenes.currentScene();
  if (current.isFinished()) {
    for (int i=0; i<scenes.size(); i++) {
      Scene s = scenes.get(i);
      if (s.needsRefresh()) {
        if (s == sequentialScene) {
          sequentialScene = nextSequentialScene;
          scenes.set(i, sequentialScene);
          s = sequentialScene;
        } else if (s == recentGlyphsScene) {
          MorphoVignette v = new MorphoVignette(previousExperiment.copy());
          v.setDataType(DataType.BIOLOGICAL);
          s.insertVignette(0, v);
        }
        s.build();
      }
    }
    scenes.nextScene();
  }

  scenes.currentScene().display();
}

void refreshScenes(ArrayList<Scene> scenesToRefresh) {
  for (Scene s : scenesToRefresh)
    s.requestRefresh();
}

void experimentNew(String uid) {
  currentExperiment.reload(uid);
  refreshScenes(currentExperimentScenes);
  println("Received new");
}

void experimentBegin(String uid) {
  currentExperiment.refresh();
  refreshScenes(currentExperimentScenes);
}

void experimentStep(String uid) {
  currentExperiment.refresh();
  refreshScenes(currentExperimentScenes);
}

void experimentEnd(String uid) {
  println("END");
  previousExperiment.reload(currentExperiment.getUid());

  refreshScenes(previousExperimentScenes);
  sequentialScene.requestRefresh();

  nextSequentialScene = new SequentialScene(previousExperiment.nImages()-1, 50);
  for (int i=0; i<previousExperiment.nImages()-1; i++) {
    GlyphVignette v = new GlyphVignette(previousExperiment);
    v.setIndex(i);
    v.noBorder();
    nextSequentialScene.putVignette(i, v);
  }

  recentGlyphsScene.requestRefresh();
}
