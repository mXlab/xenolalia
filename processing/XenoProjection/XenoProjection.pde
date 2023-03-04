final String DATA_DIR = "/home/sofian/Desktop/xenolalia/contents/"; //<>//
final int VIGNETTE_SIDE = 480;

final int WIDTH  = 1920;
final int HEIGHT = 600;

PImage DEFAULT_MASK;

DataManager manager = new DataManager();
SceneManager scenes = new SceneManager();

void setup() {
  //size(1920, 1080, P2D);
  fullScreen(P2D);

  smooth();
  DEFAULT_MASK = createVignetteMask(0);

  // Create first scene.
  ExperimentData currentExperiment = new ExperimentData("2022-10-07_13:53:30_hexagram-uqam-2022_nodepi-02");
  ExperimentData[] allExperiments = loadExperiments("/home/sofian/Desktop/xenolalia/contents/experiments.txt");

  // Single artificial image of current experiment (image on apparatus).
  if (true)
  {
    Scene scene = new Scene(1, 1);
    GlyphVignette v = new GlyphVignette(currentExperiment);
    v.setArtificialPalette(ArtificialPalette.MAGENTA);
    v.setDataType(DataType.ARTIFICIAL);
    v.build();
    scene.putVignette(0, v);
    scenes.add(scene);
  }

  // Side-by-side animation of current experiment.
  if (true)
  {
    Scene scene = new Scene(2, 1);

    MorphoVignette v;

    v= new MorphoVignette(currentExperiment);
    v.setArtificialPalette(ArtificialPalette.WHITE);
    v.setDataType(DataType.ARTIFICIAL);
    v.build();
    scene.putVignette(0, v);

    v= new MorphoVignette(currentExperiment);
    v.setDataType(DataType.BIOLOGICAL);
    v.build();
    scene.putVignette(1, v);

    scenes.add(scene);
  }

  // Single animation of alternating images from current experiment.
  if (true)
  {
    Scene scene = new Scene(1, 1);

    MorphoVignette v;

    v= new MorphoVignette(currentExperiment);
    v.setArtificialPalette(ArtificialPalette.MAGENTA);
    v.setDataType(DataType.ALL);
    v.setLastImageOffset(1);
    v.setUseInterpolation(true);
    v.build();
    scene.putVignette(0, v);

    scenes.add(scene);
  }

  // Stepwise alternating sequence of images from current experiment.
  if (true)
  {
//    Scene scene = new SequentialScene(currentExperiment.nImages()-1, 9);
    Scene scene = new SequentialScene(currentExperiment.nImages()-1, 50);
    for (int i=0; i<currentExperiment.nImages()-1; i++) {
      GlyphVignette v = new GlyphVignette(currentExperiment);
      v.setIndex(i);
      v.noBorder();
      v.build();
      scene.putVignette(i, v);
    }
    scenes.add(scene);
  }

  // Animation of recent generative glyphs.
  if (true)
  {
    Scene scene = new Scene(5, 2);
    for (int i=0; i<min(scene.nVignettes(), allExperiments.length); i++) {
      MorphoVignette v = new MorphoVignette(allExperiments[i]);
      v.setDataType(DataType.BIOLOGICAL);
      v.build();
      scene.putVignette(i, v);
    }
    scenes.add(scene);
  }
}

void draw() {
  background(0);
  //ExperimentData currentExperiment = new ExperimentData("2022-10-07_13:53:30_hexagram-uqam-2022_nodepi-02");

  //float t = map(mouseX, 0, width, 0, 1);
  //println(t);


  //PImage test;

  ////PImage test = currentExperiment.getLastBiological();
  ////image(currentExperiment.getLastBiological(), 0, 0);
  //if (keyPressed) {

  //  if (key == 'a')
  //    test = currentExperiment.getLastArtificial();
  //  else if (key == 'b')
  //    test = currentExperiment.getLastBiological();
  //  else
  //    test = lerpImage(currentExperiment.getLastArtificial().copy(),
  //      currentExperiment.getLastBiological().copy(), t);

  //  image(test, 0, 0, width, height);
  //}



  if (scenes.currentScene().isFinished())
    scenes.nextScene();

  scenes.currentScene().display();
}
