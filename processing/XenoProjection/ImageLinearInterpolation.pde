//PShader lerpShader = null;


//PImage lerpImage(PImage src, PImage dst, float t) {
//  if (lerpShader == null) {
//    lerpShader = loadShader("lerp.glsl");
//  }

//  int w = src.width;
//  int h = src.height;

//  lerpShader.set("srcSampler", src);
//  lerpShader.set("dstSampler", dst);

//  // We set the sizes of de  st and src images, and the rectangular areas
//  // from the images that we will use for blending:
//  lerpShader.set("dstSize", w, h);
//  lerpShader.set("dstRect", 0, 0, w, h);

//  lerpShader.set("srcSize", w, h);
//  lerpShader.set("srcRect", 0, 0, w, h);

//  PGraphics result = createGraphics(w, h, P2D);

//  lerpShader.set("mixFactor", t);

//  result.beginDraw();
//  result.shader(lerpShader);

//  result.pushMatrix();
//  result.noStroke();
//  result.beginShape(QUAD);
//  // Although we are not associating a texture to
//  // this shape, the uv coordinates will be stored
//  // anyways so they can be used in the fragment
//  // shader to access the destination and source
//  // images.
//  result.vertex(0, 0, 0, 0);
//  result.vertex(w, 0, 1, 0);
//  result.vertex(w, h, 1, 1);
//  result.vertex(0, h, 0, 1);
//  result.endShape();
//  result.popMatrix();
//  result.endDraw();

//  return (PImage)result;
//}

//PImage lerpImage2(PImage src, PImage dst, float t) {
//  int w = src.width;
//  int h = src.height;

//  PGraphics result = createGraphics(w, h, P2D);

//  result.beginDraw();
//  result.image(src, 0, 0, w, h);
//  //result.tint(255, (1-t)*255);
//  //result.image(dst, 0, 0);
//  result.endDraw();
  
//  return (PImage)result;
//}

// Lerp src→dst into a pre-allocated result image (no allocation, safe to call every frame).
// dst and result are resized to match src if dimensions differ.
PImage lerpImage(PImage src, PImage dst, float t, PImage result) {
  if (src == null) return dst;
  if (dst == null) return src;
  if (src == dst)  return src;
  if (dst.width != src.width || dst.height != src.height)
    dst.resize(src.width, src.height);
  if (result.width != src.width || result.height != src.height)
    result.resize(src.width, src.height);
  src.loadPixels();
  dst.loadPixels();
  result.loadPixels();
  for (int i = 0; i < result.pixels.length; i++)
    result.pixels[i] = lerpColor(src.pixels[i], dst.pixels[i], t);
  result.updatePixels();
  return result;
}

// Lerp src→dst into a newly allocated image (convenience overload; allocates each call).
PImage lerpImage(PImage src, PImage dst, float t) {
  if (src == null) return dst;
  if (dst == null) return src;
  if (src == dst)  return src;
  PImage result = createImage(src.width, src.height, ARGB);
  return lerpImage(src, dst, t, result);
}
