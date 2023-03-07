// Creates a Rect using relative values in (x,y) in [-1,1] and (w,h) in [0, 1].
Rect createRect(float relX, float relY, float relW, float relH) {
  return new Rect(map(relX, -1, 1, 0, width),map(relY, -1, 1, 0, height),
                  relW*width, relH*height);
}

class Rect {
  float x, y;
  
  float w, h;
  
  Rect() {
    this(width, height);
  }
  
  Rect(float w, float h) {
    this(width/2, height/2, w, h);
  }
  
  Rect(float x, float y, float w, float h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }
}
