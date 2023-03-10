final float VIGNETTE_RADIUS = 0.5f * VIGNETTE_SIDE;

PImage createVignetteMask(color maskColor) {
  return createVignetteMask(maskColor, 0.9);
}

PImage createVignetteMask(color maskColor, float transparencyRadius) {
  // Create a graycale transparency mask.
  PGraphics alphaMask = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
  alphaMask.beginDraw();
  alphaMask.background(255);
  alphaMask.noStroke();

  // Draw concentric circles for gradient.
  float radiusBegin = transparencyRadius * VIGNETTE_RADIUS;
  float radiusEnd   = VIGNETTE_RADIUS;
  for (float r=radiusEnd; r>radiusBegin; r--) {
    float alpha = map(r, radiusBegin, radiusEnd, 0, 255);
    alphaMask.fill(alpha);
    alphaMask.circle(VIGNETTE_RADIUS, VIGNETTE_RADIUS, 2*r);
  }

  // Draw final full white/transparent circle.
  alphaMask.fill(0);
  alphaMask.circle(VIGNETTE_RADIUS, VIGNETTE_RADIUS, 2*radiusBegin);

  alphaMask.endDraw();

  PGraphics mask = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
  mask.beginDraw();
  mask.background(maskColor);
  mask.mask(alphaMask);
  mask.endDraw();
  return mask.get();
}

abstract class Vignette {

  PGraphics pg;
  ExperimentData exp;
  Scene scene;

  PImage mask;

  float side;

  color borderColor;
  float borderWeight;
  boolean useBorder;

  DataType type;
  ArtificialPalette palette;


  Vignette(ExperimentData exp) {
    pg = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
    this.scene = null;
    this.exp = exp;
    this.mask = DEFAULT_MASK;
    this.type = DataType.ALL;
    this.useBorder = true;
    this.borderColor = color(64);
    this.borderWeight = 4;
    this.palette = ArtificialPalette.WHITE;
  }


  void setScene(Scene scene) {
    this.scene = scene;
  }

  void noBorder() {
    useBorder = false;
  }

  void setBorder(color borderColor, float borderWeight) {
    this.borderColor = borderColor;
    this.borderWeight = borderWeight;
  }

  void addMask(PImage mask) {
    this.mask = mask;
  }

  void removeMask() {
    mask = null;
  }

  boolean hasMask() {
    return mask != null;
  }

  void setDataType(DataType type) {
    this.type = type;
  }

  void setArtificialPalette(ArtificialPalette palette) {
    this.palette = palette;
  }

  void build() {
  }

  void display(float x, float y, float side, PGraphics pgTarget) {
    pg.beginDraw();
    pg.smooth();

    // Call child class display function.
    doDisplay();

    // Add mask.
    if (hasMask())
      pg.image(mask, 0, 0);

    pg.endDraw();

    // Dislay graphics.
    pgTarget.image(pg, x, y, side, side);

    // Add border.
    if (useBorder) {
      pgTarget.ellipseMode(CENTER);
      pgTarget.stroke(borderColor);
      pgTarget.strokeWeight(borderWeight);
      pgTarget.fill(0, 0);
      pgTarget.circle(x+side/2, y+side/2, side - 2*borderWeight);
    }
  }

  void doDisplay() {
  }
}
