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

PImage lerpImage(PImage src, PImage dst, float t) {
  if (src == null) return dst;
  if (dst == null) return src;
  if (src == dst)
    return src;

  int w = src.width;
  int h = src.height;

  src.loadPixels();
  dst.loadPixels();

  PImage result = createImage(w, h, ARGB);
  if (dst.width != w || dst.height != h)
    dst.resize(w, h);
  result.loadPixels();
  for (int i = 0; i < result.pixels.length; i++)
    result.pixels[i] = lerpColor(src.pixels[i], dst.pixels[i], t);
  result.updatePixels();
  return result;
}
