// NullCam: no-op camera used as fallback when GLVideo is unavailable (e.g. macOS).
// Returns a blank image so all cam.getImage() calls remain safe.
class NullCam extends AbstractCam {
  private PImage _blank;

  NullCam() {
    _blank = createImage(1, 1, RGB);
  }

  void start()        {}
  boolean available() { return false; }
  void read()         {}
  PImage getImage()   { return _blank; }
}
