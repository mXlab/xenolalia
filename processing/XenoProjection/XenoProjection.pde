final String DATA_DIR = "/home/sofian/Desktop/xenolalia/contents/";
final int VIGNETTE_SIDE = 480;

final int WIDTH  = 1920;
final int HEIGHT = 1000;

DataManager manager = new DataManager();
SceneManager scenes = new SceneManager();

void setup() {
  size(1920, 1080);
  //fullScreen();
  
  PImage mask = createVignetteMask(255);
  
  // Create first scene.
  ExperimentData currentExperiment = new ExperimentData("2022-10-07_13:53:30_hexagram-uqam-2022_nodepi-02");

  Scene scene = new Scene(1, 1);
  Vignette v = new GlyphVignette(currentExperiment);
  scene.putVignette(0, v);
  v.addMask(mask); //<>//
  scenes.add(scene);
  
  scene = new SequentialScene(currentExperiment.nImages()-1, 9);
  for (int i=0; i<currentExperiment.nImages()-1; i++) {
    v = new GlyphVignette(currentExperiment, i);
    v.addMask(mask);
    scene.putVignette(i, v);
  }
  
  scenes.add(scene);
}

void draw() {
  background(0);
  
  if (scenes.currentScene().isFinished())
    scenes.nextScene();
  
  scenes.currentScene().display();
}
