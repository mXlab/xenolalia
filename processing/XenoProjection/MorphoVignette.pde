class MorphoVignette extends Vignette {

  PImage[] images;

  MorphoVignette(ExperimentData exp) {
    super(exp);
  }

  void build() {
    images = new PImage[exp.nImages(type)];
    for (int i=0; i<images.length; i++) {
      images[i] = exp.getImage(i, type, palette);
    }
  }

  void doDisplay() {
    int imageIndex = round(scene.runProgress() * (images.length-1));
    println(imageIndex);
    pg.image(images[imageIndex], 0, 0, VIGNETTE_SIDE, VIGNETTE_SIDE);
  }
}
