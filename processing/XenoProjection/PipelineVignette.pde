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
    if (img != null) {
      pg.imageMode(CORNER);
      pg.noSmooth(); // keep pixelated look for 28x28 images
      pg.image(img, 0, 0, VIGNETTE_SIDE, VIGNETTE_SIDE);
      pg.smooth();  // restore for everything else
    } else {
      pg.background(20);
    }
  }
}
