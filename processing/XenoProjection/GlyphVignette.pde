class GlyphVignette extends Vignette {
  
  PImage img;

  GlyphVignette(ExperimentData exp) {
    this(exp, DataType.ALL, -1);
  }

  GlyphVignette(ExperimentData exp, int index) {
    this(exp, DataType.ALL, index);
  }

  GlyphVignette(ExperimentData exp, DataType type) {
    this(exp, type, -1);
  }

  GlyphVignette(ExperimentData exp, DataType type, int index) {
    super(exp);
    img = exp.getImage(index, type);
  }
  
  void doDisplay() {
     pg.image(img, 0, 0, VIGNETTE_SIDE, VIGNETTE_SIDE); //<>//
  }

}
