final String DATA_DIR = "/home/sofian/Desktop/xenolalia/contents/"; //<>//
final int VIGNETTE_SIDE = 480;

final int WIDTH  = 1920;
final int HEIGHT = 1000;

PImage DEFAULT_MASK;

DataManager manager = new DataManager();
SceneManager scenes = new SceneManager();

void setup() {
  size(1920, 1080);
  //fullScreen();

  DEFAULT_MASK = createVignetteMask(255);

  // Create first scene.
  ExperimentData currentExperiment = new ExperimentData("2022-10-07_13:53:30_hexagram-uqam-2022_nodepi-02");

  {
    Scene scene = new Scene(1, 1);
    GlyphVignette v = new GlyphVignette(currentExperiment);
    v.setArtificialPalette(ArtificialPalette.MAGENTA);
    v.setDataType(DataType.ARTIFICIAL);
    v.build();
    scene.putVignette(0, v);
    scenes.add(scene);
  }

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

  {
    Scene scene = new Scene(1, 1);

    MorphoVignette v;

    v= new MorphoVignette(currentExperiment);
    v.setArtificialPalette(ArtificialPalette.MAGENTA);
    v.setDataType(DataType.ALL);
    v.build();
    scene.putVignette(0, v);

    scenes.add(scene);
  }

  {
    Scene scene = new SequentialScene(currentExperiment.nImages()-1, 9);
    for (int i=0; i<currentExperiment.nImages()-1; i++) {
      GlyphVignette v = new GlyphVignette(currentExperiment);
      v.setIndex(i);
      v.build();
      scene.putVignette(i, v);
    }
    scenes.add(scene);
  }
}

void draw() {
  background(0);

  if (scenes.currentScene().isFinished())
    scenes.nextScene();

  scenes.currentScene().display();
}
