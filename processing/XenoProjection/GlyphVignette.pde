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
    // When type=ALL, images alternate bio/art — look up the actual type of
    // this specific index so each image gets its calibrated style.
    DataType displayType = (type == DataType.ALL && index >= 0)
        ? exp.getDataType(index)
        : type;
    drawImageWithStyle(img, getVignetteStyle(vignetteStyleKey(displayType)));
  }
}
