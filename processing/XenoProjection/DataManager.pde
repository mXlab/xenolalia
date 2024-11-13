// Provides access to images in a memory-efficient way using an image cache.
class DataManager {
  
  Map<String, PImage> imageCache = new HashMap<String, PImage>();
  
  // Returns image based on filename, using a cache.
  PImage getImage(String imageFilename) {
    if (imageCache.containsKey(imageFilename))
      return imageCache.get(imageFilename);
      
    else {
      PImage img = loadImage(imageFilename);
      imageCache.put(imageFilename, img);
      return img;
    }
  }
  
}
