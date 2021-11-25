// Contains the settings for the application.
class Settings {

  final int N_CAM_QUAD_POINTS = 4;
  PVector[] camQuadPoints = new PVector[N_CAM_QUAD_POINTS];

  final int N_IMAGE_RECT_POINTS = 2;
  PVector[] imageRectPoints = new PVector[N_IMAGE_RECT_POINTS];

  // Session.
  String nodeName;
  String sessionName;
  
  // OSC.
  int oscSendPort;
  int oscReceivePort;
  String oscRemoteIp;

  // Camera.
  int cameraId;
  int cameraWidth;
  int cameraHeight;
  
  // Generation.
  float exposureTime;
  String seedImage;
  int nFeedbackSteps;
  boolean useBaseImage;
  
  // Neural net.
  String modelName;
  boolean useConvolutional;

  Settings() {
    load();
  }

  PVector[] getCamQuadPoints() { return camQuadPoints; }
  PVector[] getImageRectPoints() { return imageRectPoints; }

  PVector getCamQuadPoint(int i) { return camQuadPoints[i]; }
  PVector getImageRectPoint(int i) { return imageRectPoints[i]; }

  int nCamQuadPoints() { return N_CAM_QUAD_POINTS; }
  int nImageRectPoints() { return N_IMAGE_RECT_POINTS; }

  String nodeName() { return nodeName; }
  String sessionName() { return sessionName; }

  int oscSendPort() { return oscSendPort; }
  int oscReceivePort()  { return oscReceivePort;}
  String oscRemoteIp() { return oscRemoteIp; }
  
  int cameraId() { return cameraId; }
  int cameraWidth() { return cameraWidth; }
  int cameraHeight() { return cameraHeight; }
  
  float exposureTime() { return exposureTime; }
  int exposureTimeMs() { return int(exposureTime*1000); }

  String seedImage()  { return seedImage; }
  int nFeedbackSteps() { return nFeedbackSteps; }
  boolean useBaseImage() { return useBaseImage; }

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

      // Save other parameters.
      settings.setString("node_name", nodeName);
      settings.setString("session_name", sessionName);
      
      settings.setInt("osc_send_port", oscSendPort);
      settings.setInt("osc_receive_port", oscReceivePort);
      settings.setString("osc_remote_ip", oscRemoteIp);
      
      
      settings.setInt("camera_id", cameraId);
      settings.setInt("camera_width", cameraWidth);
      settings.setInt("camera_height", cameraHeight);
      
      settings.setString("seed_image", seedImage);
      settings.setInt("n_feedback_steps", nFeedbackSteps);
      settings.setBoolean("use_base_image", useBaseImage);

      settings.setFloat("exposure_time", exposureTime);

      settings.setString("model_name", modelName);
      settings.setBoolean("use_convolutional", useConvolutional);

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
      // Read other parameters.
      nodeName = settings.getString("node_name");
      sessionName = settings.getString("session_name");
      
      oscSendPort = settings.getInt("osc_send_port");
      oscReceivePort = settings.getInt("osc_receive_port");
      oscRemoteIp = settings.getString("osc_remote_ip");
      
      cameraId = settings.getInt("camera_id");
      cameraWidth = settings.getInt("camera_width");
      cameraHeight = settings.getInt("camera_height");

      seedImage = settings.getString("seed_image");
      nFeedbackSteps = settings.getInt("n_feedback_steps");
      useBaseImage = settings.getBoolean("use_base_image");

      exposureTime = settings.getFloat("exposure_time");
      
      modelName = settings.getString("model_name");
      useConvolutional = settings.getBoolean("use_convolutional");
      
    } catch (Exception e) {
      println("Problem loading settings, setting to defaults: " + e);
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
    // Default values for parameters.
    oscRemoteIp = "127.0.0.1";
    oscSendPort = 7000;
    oscReceivePort = 7001;
    cameraId = 0;
    exposureTime = 60.0f;
  }

  // Writes points contained in an array of PVectors into a list of values.
  // NOTE: values are always saved in *relative coordinates* [0..1, 0..1]
  // (instead of absolute coordinates [0..width, 0..height]).
  void _writePoints(PVector[] pointsSrc, JSONArray coordDst) {
    for (int i=0; i<pointsSrc.length; i++) {
      coordDst.setFloat(i*2,   pointsSrc[i].x / width);
      coordDst.setFloat(i*2+1, pointsSrc[i].y / height);
    }
  }

  // Reads points contained as a simple list of values into array of PVectors.
  // NOTE: values are read from *relative coordinates* (see above).
  void _readPoints(PVector[] pointsDst, JSONArray coordSrc) {
    for (int i=0; i<pointsDst.length; i++) {
      pointsDst[i] = new PVector(coordSrc.getFloat(i*2)   * width,
                                 coordSrc.getFloat(i*2+1) * height);
    }
  }
}
