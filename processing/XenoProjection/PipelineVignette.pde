// Displays a single image from the CV pipeline (transform, enhance, simplify, or AE output).
class PipelineVignette extends Vignette {

  String stage;   // "0trn", "1fil", "2res", or "3ann"
  PImage img;

  PipelineVignette(ExperimentData exp, String stage) {
    super(exp);
    this.stage = stage;
    this.img   = null;
  }

  void build() {
    img = exp.getLastPipelineImage(stage);
  }

  void doDisplay() {
    pg.imageMode(CORNER);
    pg.noSmooth(); // keep pixelated look for 28x28 images
    if (palette == ArtificialPalette.MAGENTA)
      pg.tint(255, 0, 255);
    drawImageWithStyle(img, getVignetteStyle(stage));
    pg.noTint();
    pg.smooth();
  }
}
