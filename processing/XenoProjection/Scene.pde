class Scene {
  
  int nColumns;
  int nRows;
  
  Vignette[] vignettes;
  
  float duration; // duration in seconds
  
  PGraphics pg;
  float vignetteSide;
  
  Scene(int nColumns, int nRows) {
    this.nColumns = nColumns;
    this.nRows = nRows;
    
    vignettes = new Vignette[nColumns*nRows];
    
    // Find best proportions for graphics.
    float fullWidthSide  = WIDTH  / (float)nColumns;
    float fullHeightSide = HEIGHT / (float)nRows;
    
    vignetteSide = (nRows * fullWidthSide <= HEIGHT ? fullWidthSide : fullHeightSide);
    
    pg = createGraphics(WIDTH, HEIGHT);
  }
  
  int nVignettes() { return vignettes.length; }
  
  int nColumns() { return nColumns; }
  int nRows() { return nRows; }
  
  void putVignette(int c, int r, Vignette v) {
    vignettes[_getIndex(c, r)] = v;
  }
  
  void putVignette(int i, Vignette v) {
    vignettes[i] = v;
  }
  
  Vignette getVignette(int c, int r) { return vignettes[_getIndex(c, r)]; }
  
  void build() {
    
  }
  
  void reset() {}
  void display() {
    pg.beginDraw();
    
    // Call child class display function.
    doDisplay();
    
    pg.endDraw();
    
    // Dislay graphics.
    imageMode(CENTER);
    image(pg, width/2, height/2);
  }
  
  void doDisplay() {
    imageMode(CORNER);
    for (int c=0; c<nColumns; c++) {
      for (int r=0; r<nRows; r++) {
        Vignette v = getVignette(c, r);
        v.display(c*vignetteSide, r*vignetteSide, vignetteSide);
      }
    }
  }
  
  boolean isFinished() { return false; }
  
  int _getIndex(int c, int r) { return c + r*nColumns; }
}
