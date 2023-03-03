final String DATA_DIR = "/home/sofian/Desktop/xenolalia/contents/";
final int VIGNETTE_SIDE = 480;

final int WIDTH  = 800;
final int HEIGHT = 600;

DataManager manager = new DataManager();

Scene scene;

void setup() {
  size(800, 600);
  
  scene = new Scene(1, 1);
  ExperimentData test = new ExperimentData("2022-10-07_13:53:30_hexagram-uqam-2022_nodepi-02");
  Vignette v = new GlyphVignette(test, true);
  scene.putVignette(0, v);
 // fullScreen();
  v.addMask(255, 0.9); //<>//
}

void draw() {
  background(0);
  scene.display();
}
