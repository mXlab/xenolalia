abstract class Vignette {

  PGraphics pg;
  ExperimentData exp;
  
  PGraphics mask;

  Vignette(ExperimentData exp) {
    pg = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
    this.exp = exp;
    mask = null;
  }
  
  void addMask(color maskColor, float transparencyRadius) {
    color transparentColor = maskColor;
    final float VIGNETTE_RADIUS = VIGNETTE_SIDE * 0.5;
    mask = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
    mask.beginDraw();
    mask.background(maskColor);
    float radiusBegin = transparencyRadius * VIGNETTE_SIDE;
    float radiusEnd   = VIGNETTE_RADIUS;
    for (float r=radiusBegin; r<radiusEnd; r++) {
      float alpha = map(r, radiusBegin, radiusEnd, 0, 255);
      mask.fill(maskColor.red(), maskColor.green(), maskColor.blue(), alpha);
      mask.circle(VIGNETTE_RADIUS, VIGNETTE_RADIUS, 2*r);
    }
    mask.endDraw();
  }
  
  void removeMask() { mask = null; }

  boolean hasMask() { return mask != null; }
  
  void build() {
  }

  void display(float x, float y, float side) {
    pg.beginDraw();
    doDisplay();
    pg.endDraw();
    image(pg, x, y, side, side);
  }
  
  void doDisplay() {}
  
  
}
