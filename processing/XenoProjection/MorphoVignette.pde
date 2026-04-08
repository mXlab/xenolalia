class MorphoVignette extends Vignette {

  PImage[] images;
  PImage   _lerpCache = null;  // reused every frame to avoid per-frame allocation
  int lastImageOffset;
  boolean useInterpolation;
  boolean _built = false;  // true after build(); reset by requestRebuild() or dispose()

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
    if (_built) return;
    _lerpCache = null;  // force realloc: new experiment may have different image dimensions
    int nImages = max(exp.nImages(type) - lastImageOffset, 0);
    images = new PImage[nImages];
    for (int i=0; i<images.length; i++) {
      PImage img = exp.getImage(i, type, palette);
      // When interpolating a mixed bio/art sequence, pre-render each image
      // with its calibrated style into a VIGNETTE_SIDE canvas.  This makes
      // both types appear at the same content-circle size so the lerp is
      // smooth with no scale jump at the boundary.
      if (useInterpolation && type == DataType.ALL && img != null) {
        DataType dt = exp.getDataType(i);
        img = _normalizeImage(img, getVignetteStyle(vignetteStyleKey(dt)));
      }
      images[i] = img;
    }
    _built = true;
  }

  void requestRebuild() {
    _built = false;
  }

  // Composite img into a VIGNETTE_SIDE canvas using the given style's scale/bg.
  PImage _normalizeImage(PImage img, VignetteStyle style) {
    PGraphics pg = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
    pg.beginDraw();
    if (style.mode == VIGNETTE_IMG_FIT) {
      pg.background(style.bgColor);
      int s   = (int)(VIGNETTE_SIDE * style.scale);
      int off = (VIGNETTE_SIDE - s) / 2;
      pg.image(img, off, off, s, s);
    } else {
      pg.background(0);
      pg.image(img, 0, 0, VIGNETTE_SIDE, VIGNETTE_SIDE);
    }
    pg.endDraw();
    PImage result = pg.get();
    pg.dispose();
    return result;
  }

  void dispose() {
    super.dispose();
    images = null;
    _lerpCache = null;
    _built = false;
  }

  int lastImageIndex = -1;
  
  void doDisplay() {
    
    if (images.length > 0) {
      float progress = scene.runProgress();

      float imageIndex = progress * (images.length-1);
      int prevImageIndex = floor(imageIndex);
      int nextImageIndex = ceil(imageIndex);

      PImage prevImage = images[prevImageIndex];
      PImage nextImage = images[nextImageIndex];

      float t = imageIndex - prevImageIndex;
      
      if (lastImageIndex == images.length-1) {
        if (t == 0) // Send ending message when we are completely on the last image
          scene.oscSendMessage("/end", 0);
        lastImageIndex = -1;
      }
      else if (nextImageIndex != lastImageIndex) {
        if (nextImageIndex == images.length-1) {
          scene.oscSendMessage("/last"); // XXX this repeats multiple times, we could fix it using a boolean like in SequentialScene
        }
        else {
          scene.oscSendMessage("/step", nextImageIndex);
        }
        lastImageIndex = nextImageIndex;
      }

      PImage img;
      if (useInterpolation) {
        if (_lerpCache == null)
          img = _lerpCache = lerpImage(prevImage, nextImage, t);
        else
          img = lerpImage(prevImage, nextImage, t, _lerpCache);
      } else {
        img = images[round(imageIndex)];
      }
      // Style selection:
      // - Interpolated type=ALL: images were pre-normalized in build() to the
      //   same visual scale, so use FILL ("bio") for all — no per-frame resize.
      // - Non-interpolated type=ALL: snap to each image's own calibrated style.
      // - Explicit type: always use that type's style.
      DataType displayType;
      if      (type == DataType.ALL && useInterpolation)  displayType = DataType.BIOLOGICAL;
      else if (type == DataType.ALL)                      displayType = exp.getDataType(round(imageIndex));
      else                                                displayType = type;
      drawImageWithStyle(img, getVignetteStyle(vignetteStyleKey(displayType)));
    }
  }
}
