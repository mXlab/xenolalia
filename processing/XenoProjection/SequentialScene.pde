// A special kind of scene that shows a sequence of vignettes appearing from left to right,
class SequentialScene extends Scene {
  boolean lastStepDone;

  SequentialScene(int nImages, int maxImagesPerRow) {
    this(nImages, maxImagesPerRow, new Rect(width, height));
  }

  SequentialScene(int nImages, int maxImagesPerRow, Rect boundingRect) {
    super(min(nImages, maxImagesPerRow), ceil(nImages / (float)min(nImages, maxImagesPerRow)), boundingRect);
    lastStepDone = false;
  }

  void reset() {
    super.reset();
    lastStepDone = false;
  }
   
  //void initSequence(int nImages, int maxImagesPerRow) {
  //  init(min(nImages, maxImagesPerRow), ceil(nImages / (float)min(nImages, maxImagesPerRow)));
  //}

  int lastImageIndex = -1;

  void doDisplay() {
    pg.imageMode(CORNER);
    int k=0;
    int maxIndex = -1;
    for (int r=0; r<nRows; r++) {
      for (int c=0; c<nColumns; c++, k++) {
        if (map(k, 0, vignettes.length-1, 0, RUN_DURATION_PROPORTION) <= timer.progress()) {
          maxIndex = max(k, maxIndex);
          Vignette v = getVignette(c, r);
          if (v != null)
            v.display(c*vignetteSide, r*vignetteSide, vignetteSide, pg);
        }
      }
    }
  
    if (!lastStepDone) {
      if (lastImageIndex == nVignettes()-1) {
        lastStepDone = true;
        lastImageIndex = -1;
      }
      else if (maxIndex != lastImageIndex) {
        oscSendMessage("/step", maxIndex);
        lastImageIndex = maxIndex;
      }
    }
  }
}
