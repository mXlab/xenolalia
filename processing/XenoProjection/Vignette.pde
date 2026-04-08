final float VIGNETTE_RADIUS = 0.5f * VIGNETTE_SIDE;

PImage createVignetteMask(color maskColor) {
  return createVignetteMask(maskColor, 0.9);
}

// Single-zone mask: corners are OPAQUE (maskColor), gradient from the circle
// edge inward to transparencyRadius*VIGNETTE_RADIUS, transparent inside.
// Corners are opaque so maskColor clips the rectangular PGraphics to a circle.
// Use when maskColor matches the scene background (e.g. black on black).
PImage createVignetteMask(color maskColor, float transparencyRadius) {
  PGraphics alphaMask = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
  alphaMask.beginDraw();
  alphaMask.background(255);   // corners opaque
  alphaMask.noStroke();

  float radiusBegin = transparencyRadius * VIGNETTE_RADIUS;
  float radiusEnd   = VIGNETTE_RADIUS;
  for (float r = radiusEnd; r > radiusBegin; r--) {
    float alpha = map(r, radiusBegin, radiusEnd, 0, 255);
    alphaMask.fill(alpha);
    alphaMask.circle(VIGNETTE_RADIUS, VIGNETTE_RADIUS, 2*r);
  }
  alphaMask.fill(0);
  alphaMask.circle(VIGNETTE_RADIUS, VIGNETTE_RADIUS, 2*radiusBegin);
  alphaMask.endDraw();

  PGraphics mask = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
  mask.beginDraw();
  mask.background(maskColor);
  mask.mask(alphaMask);
  mask.endDraw();
  PImage result = mask.get();
  alphaMask.dispose();
  mask.dispose();
  return result;
}

// Two-zone mask: corners are TRANSPARENT so the mask color only appears
// inside the vignette circle. Use when maskColor differs from the scene bg.
//   opaqueRadius..VIGNETTE_RADIUS : fully opaque (hard band)
//   transRadius..opaqueRadius     : gradient opaque → transparent
//   inside transRadius            : fully transparent
PImage createVignetteMask(color maskColor, float opaqueRadius, float transRadius) {
  PGraphics alphaMask = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
  alphaMask.beginDraw();
  alphaMask.background(0);   // corners TRANSPARENT
  alphaMask.noStroke();

  float rOpaque = opaqueRadius * VIGNETTE_RADIUS;
  float rTransp = transRadius  * VIGNETTE_RADIUS;

  // Fill the full vignette circle opaque first (hard outer band).
  alphaMask.fill(255);
  alphaMask.circle(VIGNETTE_RADIUS, VIGNETTE_RADIUS, 2*VIGNETTE_RADIUS);

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
  PImage result = mask.get();
  alphaMask.dispose();
  mask.dispose();
  return result;
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

  void requestRebuild() {
  }

  void dispose() {
    if (pg != null) {
      pg.dispose();
      pg = null;
    }
  }

  void display(float x, float y, float side, PGraphics pgTarget) {
    pg.beginDraw();
    pg.smooth();

    // Call child class display function.
    doDisplay();

    // Add mask.
    if (_styleMask != null) {
      pg.image(_styleMask, 0, 0);          // custom style mask (e.g. white fade)
      pg.image(CIRCLE_CLIP_MASK, 0, 0);   // clip square corners to scene background
      _styleMask = null;
    } else if (mask != null) {
      pg.image(mask, 0, 0);
    }

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
      if (style.customMask != null) {
        // Clear to transparent so the scene background shows through the corners,
        // then fill only the vignette circle — prevents light bgColors from
        // bleeding as a visible rectangle outside the circle.
        pg.clear();
        pg.noStroke();
        pg.fill(style.bgColor);
        pg.circle(VIGNETTE_SIDE/2, VIGNETTE_SIDE/2, VIGNETTE_SIDE);
      } else {
        pg.background(style.bgColor);
      }
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
