import processing.video.*;

Capture cam;

PImage prevFrame;

void setup() {
  //frameRate(30); 
  //size(640, 480); // 720p  HD
  //background(200,0,200);
  background(0,0,0);
  fullScreen();
  String[] cameras = Capture.list();
  
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(cameras[i]);
    }
    
    // The camera can be initialized directly using an 
    // element from the array returned by list():
    //cam = new Capture(this, cameras[0]);
    cam = new Capture(this, "pipeline:autovideosrc");
    cam.start();     
  }      
  
  //if (cam.available()) {
  //  cam.read();

  //  // Get the capture resolution
  //  int captureWidth = cam.width;
  //  int captureHeight = cam.height;
  //  println("Capture resolution: " + captureWidth + "x" + captureHeight);
  //}
  
    noCursor();
    
}

/////////////////////////
void draw() {
  if (cam.available()) {
    cam.read();
    
    // Get the capture resolution
    int captureWidth = cam.width;
    int captureHeight = cam.height;
    
    // Calculate the crop region
    int cropSize = min(captureWidth, captureHeight);
    int cropX = (captureWidth - cropSize) / 2;
    int cropY = (captureHeight - cropSize) / 2;
    
    // Crop the image
    PImage cropped = cam.get(cropX, cropY, cropSize, cropSize);
    cropped.resize(480, 480);
    
    // Create a circular mask
    PImage mask = createImage(cropped.width, cropped.height, ALPHA);
    mask.loadPixels();
    for (int x = 0; x < mask.width; x++) {
      for (int y = 0; y < mask.height; y++) {
        float d = dist(x, y, mask.width/2, mask.height/2);
        if (d > mask.width/2) {
          mask.pixels[x + y * mask.width] = color(0, 0, 0, 0);
        } else {
          mask.pixels[x + y * mask.width] = color(255, 255, 255, 255);
        }
      }
    }
    mask.updatePixels();
    
    // Apply the mask to the cropped image
    cropped.mask(mask);
    
    // Display the masked image on the screen in the center
    image(cropped, width/2 - cropped.width/2, height/2 - cropped.height/2);
 
  }
}
