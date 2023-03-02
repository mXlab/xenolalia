class RgbMatrix {
  
  String imageFile;
  color[] matrix;
  
  RgbMatrix(String imageFile) {
    matrix = new color[SIZE];
    this.imageFile = imageFile;
    load();
  }
  
  void clear() {
    for (int i=0; i<SIZE; i++)
      matrix[i] = DEFAULT_COLOR;
  }
  
  void load() {
    PImage img = loadImage(imageFile);
    if (img != null) {
      PGraphics matrixGraphics = createGraphics(SIDE, SIDE);
      matrixGraphics.beginDraw();
      matrixGraphics.image(img, 0, 0);
      matrixGraphics.loadPixels();
      for (int i=0; i<SIZE; i++)
        matrix[i] = matrixGraphics.pixels[i];
      matrixGraphics.endDraw();
    }
    else
      clear();
  }
  
  void save(boolean send) {
    PGraphics matrixGraphics = createGraphics(SIDE, SIDE);
    matrixGraphics.beginDraw();
    matrixGraphics.loadPixels();
    for (int x=0; x<SIDE; x++) {
      for (int y=0; y<SIDE; y++) {
        matrixGraphics.pixels[x+y*SIDE] = getPixel(x, y);
      }
    }
    matrixGraphics.updatePixels();
    matrixGraphics.endDraw();
    matrixGraphics.save(imageFile);
    
    if (send)
      matrixGraphics.save(MATRIX_SEND_FILE);  
  }
  
  void send() {
    save(true);
  }
  
  void setPixel(int x, int y, int c) {
    matrix[x+y*SIDE] = c;
  }

  color getPixel(int x, int y) {
    return matrix[x+y*SIDE];
  }
}