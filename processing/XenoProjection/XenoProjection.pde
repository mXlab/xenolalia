final String DATA_DIR = "/home/sofian/Desktop/xenolalia/contents/";
final int VIGNETTE_SIDE = 480;

Vignette vignette;

void setup() {
  size(800, 800);
  ExperimentData test = new ExperimentData("2022-10-07_13:53:30_hexagram-uqam-2022_nodepi-02");
  vignette = new GlyphVignette(test, true);
}

void draw() {
  vignette.display(0, 0, 500);
}
