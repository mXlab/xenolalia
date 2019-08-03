// This mode runs the generative process through interoperability
// with python script.
class GenerativeMode extends AbstractMode {
  
  float contrast = 2.0;
  PImage img;
  boolean captureflag = false;
  
  
  color flashColor = color(255);
  
  //int flashH = 300, // magenta-ready
  //    flashS = 0, flashB = 255; // ... but starts in white
  
  PImage processedImage;
  
  boolean snapshotRequested;
  
  // Controls exposure time.
  final int EXPOSURE_TIME = 5*(60000); // 5 minutes  
  Timer exposureTimer;
  
  int capturePhase;
  
  void setup() {
    exposureTimer = new Timer(EXPOSURE_TIME);

    processedImage = createImage(OPEN_CV_WIDTH, OPEN_CV_WIDTH, RGB);
    
    requestSnapshot();
  }

  ///////////////////////////////////////
  void draw() {
  
    // Capture video.
    if (cam.available()) {
      // Update video frame.
      cam.read();
    }
    
    // Snapshot request.
    if (snapshotRequested) {
      processImage();
      captureLoop();
    }
    
    // Project current iteration.
    else {
      colorMode(RGB);
      background(0);
      drawScaledImage(img);
    }
  }
  
  ////////////////////////////////
  void captureLoop() {
  
    println("capture loop");
    if (capturePhase==0)
    {
      capturePhase = 1;
      background(flashColor);
      cam.read();
      processImage();
      // delay(1000);
    } else if (capturePhase==1) {    
      background(flashColor);
      capturePhase = 2;
      delay(1000);
    } else if (capturePhase==2) {
      snapshot();
      delay(1000);
      capturePhase = 3; // will wait for response
    }
  }
  
    /////////////////////////
  void keyPressed() {
    if (key == ' ')
      requestSnapshot();
  }  
  

  // Take a snapshot of reference image with the camera.
  void requestSnapshot() {
    println("Snapshot requested");
    snapshotRequested = true;
//    snapshotTimer.start();
    capturePhase = 0;
  }
  
  // Called when receiving OSC message.
  void nextImage(String imagePath) {
    img = loadImage(imagePath);
    snapshotRequested = false;
  }
  
  // Create filtered image using OpenCV.
  void processImage() {
    // Load the new frame of our camera in to OpenCV
    opencv.loadImage(cam.getImage());
    opencv.contrast(1.5);
    processedImage = opencv.getSnapshot();
  }
  
  void snapshot() {
    // Generate image paths.
    String basename = generateUniqueBaseName();
    String processedImageFilename = savePath("snapshots/processed_"+basename+".png");
    String rawImageFilename = savePath("snapshots/raw_"+basename+".png");
    processedImage.save(processedImageFilename);
    cam.getImage().save(rawImageFilename);
    
    // Send an OSC message to announce creation of new image.
    
    OscMessage msg = new OscMessage("/xeno/step/euglenas");
    msg.add(processedImageFilename);
    
    oscP5.send(msg, remoteLocation);
  }
}
