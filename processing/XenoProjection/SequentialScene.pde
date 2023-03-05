class SequentialScene extends Scene {

  SequentialScene(int nImages, int maxImagesPerRow) {
    this(nImages, maxImagesPerRow, new Rect(width, height));
  }
  
  SequentialScene(int nImages, int maxImagesPerRow, Rect boundingRect) {
    super(min(nImages, maxImagesPerRow), ceil(nImages / (float)min(nImages, maxImagesPerRow)), boundingRect);
  }

  void doDisplay() {
    pg.imageMode(CORNER);
    int k=0;
    for (int r=0; r<nRows; r++) {
      for (int c=0; c<nColumns; c++, k++) {
        if (map(k, 0, vignettes.length-1, 0, RUN_DURATION_PROPORTION) <= timer.progress()) {
          Vignette v = getVignette(c, r);
          if (v != null)
            v.display(c*vignetteSide, r*vignetteSide, vignetteSide, pg);
        }
      }
    }
  }
}
