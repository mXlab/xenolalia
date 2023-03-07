class MorphoVignette extends Vignette {

  PImage[] images;
  int lastImageOffset;
  boolean useInterpolation;

  MorphoVignette(ExperimentData exp) {
    super(exp);
    lastImageOffset = 0;
    useInterpolation = false;
  }

  void setLastImageOffset(int lastImageOffset) {
    this.lastImageOffset = lastImageOffset;
  }

  void setUseInterpolation(boolean useInterpolation) {
    this.useInterpolation = useInterpolation;
  }

  void build() {
    int nImages = max(exp.nImages(type) - lastImageOffset, 0);
    images = new PImage[nImages];
    for (int i=0; i<images.length; i++) {
      images[i] = exp.getImage(i, type, palette);
    }
  }

  void doDisplay() {
    float progress = scene.runProgress();
    
    float imageIndex = progress * (images.length-1);
    int prevImageIndex = floor(imageIndex);
    int nextImageIndex = ceil(imageIndex);
    
    PImage prevImage = images[prevImageIndex];
    PImage nextImage = images[nextImageIndex];
    
    float t = imageIndex - prevImageIndex;

    PImage img = useInterpolation ? lerpImage(prevImage, nextImage, t) : images[round(imageIndex)];
    pg.image(img, 0, 0, VIGNETTE_SIDE, VIGNETTE_SIDE);
  }
}
