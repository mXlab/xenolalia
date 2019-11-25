// Contains the settings for the application.
class Settings {
  
  final int N_CAM_QUAD_POINTS = 4;
  PVector[] camQuadPoints = new PVector[N_CAM_QUAD_POINTS];

  final int N_IMAGE_RECT_POINTS = 2;
  PVector[] imageRectPoints = new PVector[N_IMAGE_RECT_POINTS];
  
  Settings() {
    load();
  }
  
  PVector[] getCamQuadPoints() { return camQuadPoints; }
  PVector[] getImageRectPoints() { return imageRectPoints; }

  PVector getCamQuadPoint(int i) { return camQuadPoints[i]; }
  PVector getImageRectPoint(int i) { return imageRectPoints[i]; }
  
  int nCamQuadPoints() { return N_CAM_QUAD_POINTS; }
  int nImageRectPoints() { return N_IMAGE_RECT_POINTS; }
  
  void save() {
    try {
      JSONObject settings = new JSONObject();
      // Write camera perspective quad.
      JSONArray camQuad = new JSONArray();
      _writePoints(camQuadPoints, camQuad);
      settings.setJSONArray("camera_quad", camQuad);
      // Write image rect.
      JSONArray imageRect = new JSONArray();
      _writePoints(imageRectPoints, imageRect);
      settings.setJSONArray("image_rect", imageRect);
      // Save file.
      saveJSONObject(settings, SETTINGS_FILE_NAME);
    } catch (Exception e) {
      println("Problem saving settings: " + e + ".");
    }
  }
  
  void load() {
    try {
      JSONObject settings = loadJSONObject(SETTINGS_FILE_NAME);
      // Read camera perspective quad.
      JSONArray camQuad = settings.getJSONArray("camera_quad");
      _readPoints(camQuadPoints, camQuad);
      // Read image quad.
      JSONArray imageRect = settings.getJSONArray("image_rect");
      _readPoints(imageRectPoints, imageRect);
    } catch (Exception e) {
      println("Problem loading settings, setting to defaults.");
      reset();
      save();
    }
  }
  
  void reset() {
    // Initialize positions.
    camQuadPoints[0] = new PVector(0, 0);
    camQuadPoints[1] = new PVector(0, height);
    camQuadPoints[2] = new PVector(width, height);
    camQuadPoints[3] = new PVector(width, 0);
    // Initialize image.
    imageRectPoints[0] = new PVector(0.25*width, 0.25*height);
    imageRectPoints[1] = new PVector(0.75*width, 0.75*height);
  }

  // Writes points contained in an array of PVectors into a list of values.
  void _writePoints(PVector[] pointsSrc, JSONArray coordDst) {
    for (int i=0; i<pointsSrc.length; i++) {
      coordDst.setFloat(i*2,   pointsSrc[i].x / width);
      coordDst.setFloat(i*2+1, pointsSrc[i].y / height);
    }
  }

  // Reads points contained as a simple list of values into array of PVectors.
  void _readPoints(PVector[] pointsDst, JSONArray coordSrc) {
    for (int i=0; i<pointsDst.length; i++) {
      pointsDst[i] = new PVector(coordSrc.getFloat(i*2)   * width,
                                 coordSrc.getFloat(i*2+1) * height);
    }
  }
}
