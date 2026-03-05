final float VIGNETTE_RADIUS = 0.5f * VIGNETTE_SIDE;

PImage createVignetteMask(color maskColor) {
  return createVignetteMask(maskColor, 0.9);
}

// Single-zone mask: gradient from VIGNETTE_RADIUS inward to transparencyRadius*VIGNETTE_RADIUS,
// fully transparent inside.
PImage createVignetteMask(color maskColor, float transparencyRadius) {
  return createVignetteMask(maskColor, 1.0, transparencyRadius);
}

// Two-zone mask:
//   opaqueRadius..1.0   : fully opaque (hard band, fraction of VIGNETTE_RADIUS)
//   transRadius..opaqueRadius : gradient from opaque → transparent
//   inside transRadius  : fully transparent
PImage createVignetteMask(color maskColor, float opaqueRadius, float transRadius) {
  PGraphics alphaMask = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
  alphaMask.beginDraw();
  alphaMask.background(255);   // default: fully opaque (covers corners too)
  alphaMask.noStroke();

  float rOpaque = opaqueRadius * VIGNETTE_RADIUS;
  float rTransp = transRadius  * VIGNETTE_RADIUS;

  // Gradient zone: from rOpaque (opaque) down to rTransp (transparent).
  for (float r = rOpaque; r > rTransp; r--) {
    float alpha = map(r, rTransp, rOpaque, 0, 255);
    alphaMask.fill(alpha);
    alphaMask.circle(VIGNETTE_RADIUS, VIGNETTE_RADIUS, 2*r);
  }

  // Fully transparent inside rTransp.
  alphaMask.fill(0);
  alphaMask.circle(VIGNETTE_RADIUS, VIGNETTE_RADIUS, 2*rTransp);

  alphaMask.endDraw();

  PGraphics mask = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
  mask.beginDraw();
  mask.background(maskColor);
  mask.mask(alphaMask);
  mask.endDraw();
  return mask.get();
}

// A vignette presents a single experiment using a specitic kind of view (defined by the subclass).
abstract class Vignette {

  PGraphics pg;
  ExperimentData exp;
  Scene scene;

  PImage mask;
  PImage _styleMask;  // set by drawImageWithStyle(); consumed by display()

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
    this.mask       = DEFAULT_MASK;
    this._styleMask = null;
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

    // Add mask: prefer per-style override, fall back to vignette default.
    PImage activeMask = (_styleMask != null) ? _styleMask : mask;
    _styleMask = null;
    if (activeMask != null)
      pg.image(activeMask, 0, 0);

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

  // Render img using the given VignetteStyle onto pg.
  // Must be called from within a pg.beginDraw() / pg.endDraw() block.
  // If style.customMask is set, records it so display() uses it instead of
  // the vignette's own mask.
  void drawImageWithStyle(PImage img, VignetteStyle style) {
    if (img == null) {
      pg.background(20);
      return;
    }
    if (style.mode == VIGNETTE_IMG_FIT) {
      pg.background(style.bgColor);
      int s   = (int)(VIGNETTE_SIDE * style.scale);
      int off = (VIGNETTE_SIDE - s) / 2;
      pg.image(img, off, off, s, s);
    } else {
      pg.image(img, 0, 0, VIGNETTE_SIDE, VIGNETTE_SIDE);
    }
    if (style.customMask != null)
      _styleMask = style.customMask;
  }

  void doDisplay() {
  }

  String toString() {
    return exp.getUid();
  }

  ExperimentData getExperimentData() { return exp; }
}
