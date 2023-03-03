abstract class Vignette {

  PGraphics pg;
  ExperimentData exp;

  Vignette(ExperimentData exp) {
    pg = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
    this.exp = exp;
  }

  void build() {
  }

  void display(float x, float y, float side) {
    pg.beginDraw();
    doDisplay();
    pg.endDraw();
    image(pg, x, y, side, side);
  }
  
  void doDisplay() {}
}
