// Defines how an image is rendered inside a vignette circle.
//
// FILL : image is stretched to cover the full VIGNETTE_SIDE × VIGNETTE_SIDE
//        area; the vignette's circular mask clips it to a disc.
//        Use for images that are already circular (bio, ann display files).
//        For real photo images (col, bsb, 0trn), FIT is used with a
//        customMask that has a wider gradient to fade the square corners.
//
// FIT  : a solid background fills the vignette circle first, then the image
//        is drawn centred at `scale` × VIGNETTE_SIDE, giving breathing room
//        around the content disc.
//        Use for square pipeline images whose content circle is inscribed
//        in a 224×224 square (1fil, 2res, 3ann, 4prj).

final int VIGNETTE_IMG_FILL = 0;
final int VIGNETTE_IMG_FIT  = 1;

class VignetteStyle {
  int    mode;
  color  bgColor;
  float  scale;       // fraction of VIGNETTE_SIDE used for the image (FIT only)
  PImage customMask;  // if non-null, replaces the vignette's default mask (FILL only)

  VignetteStyle(int mode) {
    this(mode, color(0), 1.0, null);
  }
  VignetteStyle(int mode, color bgColor, float scale) {
    this(mode, bgColor, scale, null);
  }
  // FILL mode with custom mask (no bgColor / scale needed)
  VignetteStyle(int mode, PImage customMask) {
    this(mode, color(0), 1.0, customMask);
  }
  VignetteStyle(int mode, color bgColor, float scale, PImage customMask) {
    this.mode       = mode;
    this.bgColor    = bgColor;
    this.scale      = scale;
    this.customMask = customMask;
  }
}

// -----------------------------------------------------------------------
// Lookup table: pipeline-stage suffix  →  VignetteStyle
// Add or adjust entries here to change how each stage looks.
// -----------------------------------------------------------------------
HashMap<String, VignetteStyle> vignetteStyles;

void initVignetteStyles() {
  vignetteStyles = new HashMap<String, VignetteStyle>();

  // --- Category 1: Already-circular images ------------------------------
  // bio / ann: produced with fit-in-circle; the default vignette mask
  // clips them cleanly.
  vignetteStyles.put("bio", new VignetteStyle(VIGNETTE_IMG_FILL));
  vignetteStyles.put("ann", new VignetteStyle(VIGNETTE_IMG_FILL));

  // --- Category 2: Real photo images (square crop, unpredictable bg) ---
  // col / bsb / 0trn: FIT with a dark background, but with a wide-gradient
  // mask (transparencyRadius=0.65) that softly fades the square corners
  // instead of leaving a hard circle edge.
  PImage wideGradMask = createVignetteMask(color(0), 0.65);
  vignetteStyles.put("col",  new VignetteStyle(VIGNETTE_IMG_FIT, color(20), 0.85, wideGradMask));
  vignetteStyles.put("bsb",  new VignetteStyle(VIGNETTE_IMG_FIT, color(20), 0.85, wideGradMask));
  vignetteStyles.put("0trn", new VignetteStyle(VIGNETTE_IMG_FIT, color(20), 0.85, wideGradMask));

  // --- Category 3: CV pipeline / neural-network output stages -----------
  // Square 224×224 images; content disc inscribed.  Add breathing room
  // with a solid dark background.
  vignetteStyles.put("1fil", new VignetteStyle(VIGNETTE_IMG_FIT, color(0),  0.85));
  vignetteStyles.put("2res", new VignetteStyle(VIGNETTE_IMG_FIT, color(0),  0.85));
  vignetteStyles.put("3ann", new VignetteStyle(VIGNETTE_IMG_FIT, color(0),  0.85));
  // 4prj: postprocessed + squircle-mapped disc on black bg.
  vignetteStyles.put("4prj", new VignetteStyle(VIGNETTE_IMG_FIT, color(0),  0.85));
}

// Returns the style for a given stage/type key, defaulting to FILL.
VignetteStyle getVignetteStyle(String key) {
  if (vignetteStyles != null && vignetteStyles.containsKey(key))
    return vignetteStyles.get(key);
  return new VignetteStyle(VIGNETTE_IMG_FILL);
}

// Convenience: DataType → style key.
String vignetteStyleKey(DataType type) {
  switch (type) {
    case BIOLOGICAL: return "bio";
    case ARTIFICIAL: return "4prj";
    default:         return "bio";
  }
}
