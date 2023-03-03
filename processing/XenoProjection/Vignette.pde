abstract class Vignette {

  final float VIGNETTE_RADIUS = 0.5f * VIGNETTE_SIDE;

  PGraphics pg;
  ExperimentData exp;
  
  PGraphics mask;
  
  float side;

  Vignette(ExperimentData exp) {
    pg = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
    this.exp = exp;
    mask = null;
  }
  
  void addMask(color maskColor) {
    addMask(maskColor, 0.9);
  }
  
  void addMask(color maskColor, float transparencyRadius) {
    // Create a graycale transparency mask.
    PGraphics alphaMask = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE); //<>//
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
    
    mask = createGraphics(VIGNETTE_SIDE, VIGNETTE_SIDE);
    mask.beginDraw();
    mask.background(maskColor);
    mask.mask(alphaMask);
    mask.endDraw();
  }
  
  void removeMask() {
    mask = null; 
  }

  boolean hasMask() { return mask != null; }
  
  void build() {
  }

  void display(float x, float y, float side) {
    pg.beginDraw();
    
    // Call child class display function.
    doDisplay();
    
    // Add mask.
    if (hasMask())
      pg.image(mask, 0, 0);
    pg.endDraw();
    
    // Dislay graphics.
    image(pg, x, y, side, side);
  }
  
  void doDisplay() {}
  
  
}
