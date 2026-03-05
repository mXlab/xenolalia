// Defines how an image is rendered inside a vignette circle.
//
// FILL : image is stretched to cover the full VIGNETTE_SIDE × VIGNETTE_SIDE
//        area; the vignette's circular mask clips it to a disc.
//        Use for images that are already circular (bio, 4prj, ann display files).
//
// FIT  : a solid background fills the vignette circle first, then the image
//        is drawn centred at `scale` × VIGNETTE_SIDE, giving breathing room
//        around the content disc.
//        Use for square pipeline images whose content circle is inscribed
//        in a 224×224 square (col, bsb, 0trn, 1fil, 2res, 3ann).

final int VIGNETTE_IMG_FILL = 0;
final int VIGNETTE_IMG_FIT  = 1;

class VignetteStyle {
  int   mode;
  color bgColor;
  float scale;   // fraction of VIGNETTE_SIDE used for the image (FIT only)

  VignetteStyle(int mode) {
    this(mode, color(0), 1.0);
  }
  VignetteStyle(int mode, color bgColor, float scale) {
    this.mode    = mode;
    this.bgColor = bgColor;
    this.scale   = scale;
  }
}

// -----------------------------------------------------------------------
// Lookup table: pipeline-stage suffix  →  VignetteStyle
// Add or adjust entries here to change how each stage looks.
// -----------------------------------------------------------------------
HashMap<String, VignetteStyle> vignetteStyles;

void initVignetteStyles() {
  vignetteStyles = new HashMap<String, VignetteStyle>();

  // --- Biological / color camera images ---------------------------------
  // Already circular after fit-in-circle pre-processing; let the vignette
  // mask do the work.
  vignetteStyles.put("bio", new VignetteStyle(VIGNETTE_IMG_FILL));
  vignetteStyles.put("col", new VignetteStyle(VIGNETTE_IMG_FIT,  color(0),  0.85));

  // --- CV pipeline processing stages ------------------------------------
  // Square 224×224 images; content disc inscribed.  Add breathing room.
  vignetteStyles.put("bsb",  new VignetteStyle(VIGNETTE_IMG_FIT, color(20), 0.85));
  vignetteStyles.put("0trn", new VignetteStyle(VIGNETTE_IMG_FIT, color(20), 0.85));
  vignetteStyles.put("1fil", new VignetteStyle(VIGNETTE_IMG_FIT, color(0),  0.85));
  vignetteStyles.put("2res", new VignetteStyle(VIGNETTE_IMG_FIT, color(0),  0.85));

  // --- Neural network output stages -------------------------------------
  // 3ann: raw 28×28 square AE output, scaled up pixelated.
  vignetteStyles.put("3ann", new VignetteStyle(VIGNETTE_IMG_FIT, color(0),  0.85));
  // 4prj: postprocessed + squircle-mapped disc on black bg.
  vignetteStyles.put("4prj", new VignetteStyle(VIGNETTE_IMG_FIT, color(0), 0.85));

  // --- Pre-generated display images -------------------------------------
  // _ann_N.png: generated with fit_in_circle → already circular.
  vignetteStyles.put("ann",  new VignetteStyle(VIGNETTE_IMG_FILL));
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
