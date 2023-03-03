class GlyphVignette extends Vignette {
  
  PImage img;

  GlyphVignette(ExperimentData exp) {
    this(exp, false, -1);
  }

  GlyphVignette(ExperimentData exp, boolean useArtificial) {
    this(exp, useArtificial, -1);
  }

  GlyphVignette(ExperimentData exp, boolean useArtificial, int index) {
    super(exp);
    img = useArtificial ? exp.getArtificial(index) : exp.getBiological(index);
  }
  
  void doDisplay() {
     pg.image(img, 0, 0, VIGNETTE_SIDE, VIGNETTE_SIDE); //<>//
  }

}
