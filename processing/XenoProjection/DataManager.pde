// Provides access to images in a memory-efficient way using a bounded LRU image cache.
class DataManager {

  final int IMAGE_CACHE_MAX = 200;

  // Access-ordered LinkedHashMap: least-recently-used entry is evicted when full.
  Map<String, PImage> imageCache = new java.util.LinkedHashMap<String, PImage>(16, 0.75f, true) {
    protected boolean removeEldestEntry(java.util.Map.Entry<String, PImage> eldest) {
      return size() > IMAGE_CACHE_MAX;
    }
  };

  // Returns image based on filename, using a cache.
  PImage getImage(String imageFilename) {
    if (imageCache.containsKey(imageFilename))
      return imageCache.get(imageFilename);

    PImage img = loadImage(imageFilename);
    imageCache.put(imageFilename, img);
    return img;
  }

}
