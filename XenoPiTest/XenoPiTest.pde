/** 
 * This program allows to run different image projection tests on the Euglena petri dish and
 * to capture results on camera.
 *
 * The program allows to use either of these two libraries. On RPi we recommend
 * using GL Video.
 *  
 * (c) TeZ & Sofian Audry
 *
 *  For use with the Raspberry Pi camera, make sure the camera is
 *  enabled in the Raspberry Pi Configuration tool and add the line
 *  "bcm2835_v4l2" (without quotation marks) to the file
 *  /etc/modules. After a restart you should be able to see the
 *  camera device as /dev/video0.
 */

/////
// import hypermedia.video.*;
import gab.opencv.*;
OpenCV opencv;
float scalefactor = 0.35, scaleX = 1.0, scaleY = 1.0 ;
float contrast = 2.0;
int threshold = 100;
boolean useAdaptiveThreshold = false; // use basic thresholding

boolean bSwitch = true;
boolean srcswitch = true;
int thresholdBlockSize = 489;
int thresholdConstant = 45;
int blurSize = 4;
IntList bAreas;
IntList bX;
IntList bY;
int xID=0;
int xArea=0;
/////
import gohai.glvideo.*;
GLCapture video;
PImage img;  // Declare variable "a" of type PImage
int imagenum = 0;
boolean captureflag = false;
int capturephase = 0;
int capwidth, capheight; 

int camviewwidth, camviewheight;

enum CameraMode {
  None, // default mode: no camera display
  Test, // test mode: display camera in corner
  Processed,  // processed mode: display camera in corner with filter
}

CameraMode cameraMode = CameraMode.None;
boolean flash = false; // when in "flash" mode the background is displayed instead of image

color flashColor;
int flashH = 300, // magenta-ready
    flashS = 0, flashB = 255; // ... but starts in white

PImage newImage; 

PImage src, preProcessedImage, processedImage, contoursImage;
//record time-lapse 
boolean record = false;
boolean invert = true;

// All image patterns.
String imagez[]={
  "xeno-pattern-00.jpg", // 0 (default)
  "xeno-pattern-01.jpg", // 1 
  "xeno-pattern-02.jpg", // 2
  "xeno-pattern-03.jpg", // 3
  "xeno-pattern-04.jpg", // 4
  "xeno-pattern-05.jpg", // 5
  "xeno-pattern-06.jpg", // 6
};


///////////////////////////////////////
void setup() {


  background(0);
  //size(800, 600, P2D);
  //size(480, 320, P2D);
  fullScreen(P2D);

  capwidth = capheight = 320;
  camviewwidth = camviewheight = 100;

  newImage = createImage(width, height, RGB);
  processedImage = createImage(capwidth, capheight, RGB);

  String[] devices = GLCapture.list();
  println("Devices:");
  printArray(devices);
  if (0 < devices.length) {
    String[] configs = GLCapture.configs(devices[0]);
    println("Configs:");
    printArray(configs);
  }

  // this will use the first recognized camera by default
  //  video = new GLCapture(this, devices[0], width, height);
  video = new GLCapture(this, devices[0], capwidth, capheight);

  // you could be more specific also, e.g.
  //video = new GLCapture(this, devices[0]);
  //video = new GLCapture(this, devices[0], 640, 480, 25);
  //video = new GLCapture(this, devices[0], configs[0]);

  video.start();
  
  updateFlashColor();

  // Load default image into the program.
  loadImage();

  // opencv = new OpenCV(this, width, height);
  opencv = new OpenCV(this, capwidth, capheight);
  
  //frameRate(10);
}



int xxx=0;
///////////////////////////////////////
void draw() {

  // Capture video.
  if (video.available() && (captureflag || cameraMode != CameraMode.None)) {
    // Update video frame.
    video.read();
  }
  
  // Snapshot requested.
  if (captureflag) {
    processImage();
    captureLoop();
  } else {
    // Display background or projected image depending on flash status.
    if (flash) { // flash!
      colorMode(HSB, 360, 255,255);
      background(flashColor);
    }
    else { // project image onto petri dish
      colorMode(RGB);
      background(0);
      int ww=(width - img.width) /2;
      int hh=(height - img.height)/2;    
      image(img, ww, hh);
    }
    
    if (cameraMode != CameraMode.None) {
      processImage();
      image(video, 0, 0, camviewwidth, camviewheight);
      image(processedImage, 0, camviewheight, camviewwidth, camviewheight);
    }
  }
}

////////////////////////////////
void captureLoop() {

  println("capture loop");
  if (capturephase==0)
  {
    capturephase = 1;
    background(flashColor);
    video.read();
    processImage();
    // delay(1000);
  } else if (capturephase==1) {    
    background(flashColor);
    capturephase = 2;
    delay(1000);
  } else if (capturephase==2) {   
    //newImage = processedImage.copy();
    // newImage.save("/home/pi/sketchbook/tezzy/xenopi/vid-cap.jpg");
    snapshot();
    delay(1000);
    capturephase = 0;
    captureflag = false;
    loadImage();
  }
}

/////////////////////////
void keyPressed() {

  // Normal mode.
  if (key == 'n') {
    cameraMode = CameraMode.None;
  }
  
  // Processed mode.
  else if (key == 'p') {
    cameraMode = CameraMode.Processed;
  }
  
  // Test mode.
  else if (key == 't') {
    cameraMode = CameraMode.Test;
  }
  
  // Flash (toggle).
  else if (key == 'f') {
    flash = !flash;
  }
  
  // Video capture mode (activates processed cam + flash).
  else if (key == 'v') {
    cameraMode = CameraMode.Processed;
    flash = true;
  }
  
  else if (key == 'H') {
    flashH = (flashH + 30) % 360;
  }

  else if (key == 'h') {
    flashH = (flashH - 30 + 360) % 360;
    println(flashH);
  }
  
  else if (key == 'S') {
    flashS = constrain(flashS + 25, 0, 255);
  }
  
  else if (key == 's') {
    flashS = constrain(flashS - 25, 0, 255);
  }

  else if (key == 'B') {
    flashB = constrain(flashB + 25, 0, 255);
  }
  
  else if (key == 'b') {
    flashB = constrain(flashB - 25, 0, 255);
  }

  // get up to full color
  else if (key == 'c') {
    flashS = flashB = 255;
  }
  
  // revert back to white background
  else if (key == 'w') {
    flashS = 0;
    flashB = 255;
  }
  
  else if (key == '+') {
    scalefactor = constrain(scalefactor + 0.05, 0.05, 2);
    loadImage();
  }
  
  else if (key == '-') {
    scalefactor = constrain(scalefactor - 0.05, 0.05, 2);
    loadImage();
  }
  
  //// Take a snapshot.
  //else if (key == ' ') {
  //  snapshot(true);
  //}
  
  // Directly change to image number.
  else if ('0' <= key && key <= '9') {
    captureflag = false;
    imagenum = constrain((int)(key - '0'), 0, imagez.length-1);
    loadImage();
  }
  
  // Other keys.
  else if (key == CODED) {
    // Image caroussel: ->
    if (keyCode == RIGHT) {
      captureflag = false;
      if (imagenum <(imagez.length -1))
        imagenum++;
      else {
        imagenum = 0;
      }
      loadImage();
    // Image caroussel: <-
    } else if (keyCode == LEFT) {
      captureflag = false;
      if (imagenum > 0)
        imagenum--;
      else {
        imagenum = imagez.length -1;
      }
      loadImage();
    // Start capture.
    } else if (keyCode == UP) {
      print("UP");
      captureflag = true;
      // Captureimage();
    // Stop capture.
    } else if (keyCode == DOWN) {
      print("DOWN");
      captureflag = false;
    }
  }
  
  updateFlashColor();
}  

void setImageNum(int n) {
  imagenum = constrain(n, 0, imagez.length-1);
}

/////////////////////////
void loadImage() {
  pushMatrix();
  img = loadImage(imagez[imagenum]);
  img.resize(round(scalefactor*img.width), round(scalefactor*img.height));
  popMatrix();
}

void updateFlashColor() {
  colorMode(HSB, 360, 255, 255);
  flashColor = color(flashH, flashS, flashB);
}

//////////////////////
void processImage() {

  // Load the new frame of our camera in to OpenCV
  // opencv.useColor();
  opencv.loadImage(video);
  //opencv.copy(video); 


  // Flips the image horizontally 
  //  opencv.flip(OpenCV.HORIZONTAL); 
  // opencv.flip(OpenCV.VERTICAL); 
  //  src = opencv.getSnapshot();



  ///////////////////////////////
  // <1> PRE-PROCESS IMAGE
  // - Grey channel 
  // - Brightness / Contrast
  ///////////////////////////////

  // Gray channel
  // opencv.gray();
  //opencv.brightness(brightness);
  // opencv.contrast(contrast);
  opencv.contrast(1.5);

  ///////////////////////////////
  // <2> PROCESS IMAGE
  // - Threshold
  // - Noise Supression
  ///////////////////////////////

  //  // Adaptive threshold - Good when non-uniform illumination
  //  if (useAdaptiveThreshold) {

  //    // Block size must be odd and greater than 3
  //    if (thresholdBlockSize%2 == 0) thresholdBlockSize++;
  //    if (thresholdBlockSize < 3) thresholdBlockSize = 3;

  //    opencv.adaptiveThreshold(thresholdBlockSize, thresholdConstant);

  //    // Basic threshold - range [0, 255]
  //  } else {
  //    opencv.threshold(threshold);
  //  }

  //  if(invert){s
  //  // Invert (black bg, white blobs)
  //  opencv.invert();
  //  }

  //  // Reduce noise - Dilate and erode to close holes
  //  opencv.dilate();
  //  opencv.erode();

  //  // Blur
  //  opencv.blur(blurSize);


  // Save snapshot for display
  //   processedImage = opencv.getSnapshot();

  ///////////////////////////////
  // <3> FIND CONTOURS  
  ///////////////////////////////

  //detectBlobs();
  //// Passing 'true' sorts them by descending area.
  ////contours = opencv.findContours(true, true);
  //// Save snapshot for display
  //contoursImage = opencv.getSnapshot();

  processedImage = opencv.getSnapshot();
}

void snapshot() {
  String basename = generateUniqueBaseName();
  processedImage.save(savePath("snapshots/"+basename+"_pro.png"));
  video.save(savePath("snapshots/"+basename+"_raw.png"));
}

String generateUniqueBaseName() {
  return nf(year(),4)+"-"+nf(month(),2)+"-"+nf(day(),2)+"_"+
           nf(hour(),2)+":"+nf(minute(),2)+":"+nf(second(),2)+"_"+nf(millis(),6);
}  
