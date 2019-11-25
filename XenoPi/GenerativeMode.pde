// This mode runs the generative process through interoperability
// with python script.
class GenerativeMode extends AbstractMode {
  
  float contrast = 2.0;
  PImage img;
  boolean captureflag = false;
  
  boolean flash = false;
  boolean camView = false;
  
  boolean autoMode = true;
  
  final int CAM_VIEW_WIDTH = 200;
  final int CAM_VIEW_HEIGHT = 200;
  
  color flashColor = color(255);
    
  final color PROJECTION_COLOR = color(#ff00ff); // magenta
  //int flashH = 300, // magenta-ready
  //    flashS = 0, flashB = 255; // ... but starts in white
  
  PImage processedImage;
  
  boolean snapshotRequested;
  int nSnapshots;

  // Controls exposure time (time between each snapshot)
  final int EXPOSURE_TIME = 1 * (60000);  
  Timer exposureTimer;
  
  int capturePhase;
  
  String experimentName;
  
  void setup() {
    processedImage = createImage(OPEN_CV_WIDTH, OPEN_CV_WIDTH, RGB);
    
    // Create a unique name for experiment.
    experimentName = generateUniqueBaseName();
    
    // Take a first snapshot.
    nSnapshots = 0;
    exposureTimer = new Timer(EXPOSURE_TIME);
    requestSnapshot();
    exposureTimer.start();
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
      //processImage();
      captureLoop();
    }
    
    // Project current iteration.
    else {
      
      if (autoMode && exposureTimer.isFinished()) {
        requestSnapshot();
        exposureTimer.start();
      }
      
      // Display background or projected image depending on flash status.
      if (flash) { // flash!
        background(flashColor);
      } else { // projected image
        background(0);
        tint(PROJECTION_COLOR); // tint
        drawScaledImage(img);
      }
      
      // Camera view in the top-left corner.
      if (camView) {
        noTint();
        imageMode(CORNER);
        image(cam.getImage(), 0, 0, CAM_VIEW_WIDTH, CAM_VIEW_HEIGHT);
      }
      
      fill(255);
      textSize(32);
      String status;
      if (autoMode)
        status = "time until next snapshot: " + nf(exposureTimer.countdownTime()/1000.0f, 3, 1) + " s";
      else
        status = "manual mode";
      text(status, 10, height-10);
      
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
      //processImage();
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
    else if (key == 'f')
      flash = !flash;
    else if (key == 'v')
      camView = !camView;
    else if (key == 'a') {
      autoMode = !autoMode;
    }
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
    String basename = "snapshot_"+nSnapshots+"_"+nf(millis(), 6);
    String prefix = "snapshots/"+experimentName+"/"+basename;
    String processedImageFilename = savePath(prefix+"_pro.png");
    String rawImageFilename = savePath(prefix+"_raw.png");
    //processedImage.save(processedImageFilename);
    cam.getImage().save(rawImageFilename);
    
    // Send an OSC message to announce creation of new image.
    
    OscMessage msg = new OscMessage("/xeno/euglenas/" + 
      ((nSnapshots == 0 && !EUGLENAS_BEGIN) ? "begin" : "step"));
//    msg.add(processedImageFilename);
    msg.add(rawImageFilename);
    
    oscP5.send(msg, remoteLocation);
    
    nSnapshots++;
  }
}
