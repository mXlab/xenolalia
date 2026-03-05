class GlyphVignette extends Vignette {

  PImage img;

  int index;

  GlyphVignette(ExperimentData exp) {
    super(exp);
    this.index = -1;
  }

  void setIndex(int index) {
    this.index = index;
  }

  void build() {
    img = exp.getImage(index, type, palette);
  }

  void doDisplay() {
    pg.ellipseMode(CORNER);
    drawImageWithStyle(img, getVignetteStyle(vignetteStyleKey(type)));
  }
}
