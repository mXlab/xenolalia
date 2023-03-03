final String DATA_DIR = "/home/sofian/Desktop/xenolalia/contents/";
final int VIGNETTE_SIDE = 480;

final int WIDTH  = 1920;
final int HEIGHT = 1000;

DataManager manager = new DataManager();

Scene scene;

void setup() {
  size(1920, 1080);
  //fullScreen();
  
  PImage mask = createVignetteMask(255);
  
  scene = new Scene(1, 1);
  ExperimentData test = new ExperimentData("2022-10-07_13:53:30_hexagram-uqam-2022_nodepi-02");
  Vignette v = new GlyphVignette(test);
  scene.putVignette(0, v);
  v.addMask(mask); //<>//
  
  scene = new SequentialScene(test.nImages()-1, 9);
  for (int i=0; i<test.nImages()-1; i++) {
    v = new GlyphVignette(test, i);
    v.addMask(mask);
    scene.putVignette(i, v);
  }
  
  scene.reset();
}

void draw() {
  background(0);
  if (!scene.isFinished())
    scene.display();
}
