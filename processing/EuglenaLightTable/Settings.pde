/**
 * Settings
 *
 * Handles JSON configuration persistence for EuglenaLightTable.
 * Saves state, shape, color, and width for each dish.
 */
class Settings {
  String filepath;

  // Saved settings for each dish
  int[] dishStates      = new int[12];
  int[] dishShapes      = new int[12];
  int[] dishColors      = new int[12];
  int[] dishWidths      = new int[12];
  int[] dishLightness   = new int[12];
  int[] dishEnabled     = new int[12];  // 1 = enabled, 0 = disabled
  int[] dishHueOffsets    = new int[12];
  int[] dishSaturations   = new int[12];

  Settings(String filepath) {
    this.filepath = filepath;
    // Initialize to defaults
    for (int i = 0; i < 12; i++) {
      dishStates[i]     = DishSpot.STATE_WHITE;
      dishShapes[i]     = DishSpot.SHAPE_X;
      dishColors[i]     = DishSpot.COLOR_WHITE;
      dishWidths[i]     = DishSpot.WIDTH_MEDIUM;
      dishLightness[i]  = DishSpot.LIGHTNESS_100;
      dishEnabled[i]    = 1;
      dishHueOffsets[i]  = 0;
      dishSaturations[i] = 100;
    }
  }

  void load() {
    File f = new File(filepath);
    if (!f.exists()) {
      println("Settings file not found, using defaults: " + filepath);
      return;
    }

    try {
      JSONObject json = loadJSONObject(filepath);

      // Load dish states
      if (json.hasKey("dishStates")) {
        JSONArray arr = json.getJSONArray("dishStates");
        for (int i = 0; i < min(arr.size(), 12); i++) {
          dishStates[i] = arr.getInt(i);
        }
      }

      // Load dish shapes
      if (json.hasKey("dishShapes")) {
        JSONArray arr = json.getJSONArray("dishShapes");
        for (int i = 0; i < min(arr.size(), 12); i++) {
          dishShapes[i] = arr.getInt(i);
        }
      }

      // Load dish colors
      if (json.hasKey("dishColors")) {
        JSONArray arr = json.getJSONArray("dishColors");
        for (int i = 0; i < min(arr.size(), 12); i++) {
          dishColors[i] = arr.getInt(i);
        }
      }

      // Load dish widths
      if (json.hasKey("dishWidths")) {
        JSONArray arr = json.getJSONArray("dishWidths");
        for (int i = 0; i < min(arr.size(), 12); i++) {
          dishWidths[i] = arr.getInt(i);
        }
      }

      // Load dish lightness
      if (json.hasKey("dishLightness")) {
        JSONArray arr = json.getJSONArray("dishLightness");
        for (int i = 0; i < min(arr.size(), 12); i++) {
          dishLightness[i] = arr.getInt(i);
        }
      }

      // Load dish enabled flags
      if (json.hasKey("dishEnabled")) {
        JSONArray arr = json.getJSONArray("dishEnabled");
        for (int i = 0; i < min(arr.size(), 12); i++) {
          dishEnabled[i] = arr.getInt(i);
        }
      }

      // Load dish hue offsets (optional — defaults to 0)
      if (json.hasKey("dishHueOffsets")) {
        JSONArray arr = json.getJSONArray("dishHueOffsets");
        for (int i = 0; i < min(arr.size(), 12); i++) {
          dishHueOffsets[i] = arr.getInt(i);
        }
      }

      // Load dish saturations (optional — defaults to 100)
      if (json.hasKey("dishSaturations")) {
        JSONArray arr = json.getJSONArray("dishSaturations");
        for (int i = 0; i < min(arr.size(), 12); i++) {
          dishSaturations[i] = arr.getInt(i);
        }
      }

      println("Settings loaded from: " + filepath);
    } catch (Exception e) {
      println("Error loading settings: " + e.getMessage());
    }
  }

  void save() {
    try {
      JSONObject json = new JSONObject();

      // Save dish states
      JSONArray states = new JSONArray();
      for (int i = 0; i < 12; i++) states.setInt(i, dishStates[i]);
      json.setJSONArray("dishStates", states);

      // Save dish shapes
      JSONArray shapes = new JSONArray();
      for (int i = 0; i < 12; i++) shapes.setInt(i, dishShapes[i]);
      json.setJSONArray("dishShapes", shapes);

      // Save dish colors
      JSONArray colors = new JSONArray();
      for (int i = 0; i < 12; i++) colors.setInt(i, dishColors[i]);
      json.setJSONArray("dishColors", colors);

      // Save dish widths
      JSONArray widths = new JSONArray();
      for (int i = 0; i < 12; i++) widths.setInt(i, dishWidths[i]);
      json.setJSONArray("dishWidths", widths);

      // Save dish lightness
      JSONArray lightness = new JSONArray();
      for (int i = 0; i < 12; i++) lightness.setInt(i, dishLightness[i]);
      json.setJSONArray("dishLightness", lightness);

      // Save dish enabled flags
      JSONArray enabled = new JSONArray();
      for (int i = 0; i < 12; i++) enabled.setInt(i, dishEnabled[i]);
      json.setJSONArray("dishEnabled", enabled);

      // Save dish hue offsets
      JSONArray hueOffsets = new JSONArray();
      for (int i = 0; i < 12; i++) hueOffsets.setInt(i, dishHueOffsets[i]);
      json.setJSONArray("dishHueOffsets", hueOffsets);

      // Save dish saturations
      JSONArray saturations = new JSONArray();
      for (int i = 0; i < 12; i++) saturations.setInt(i, dishSaturations[i]);
      json.setJSONArray("dishSaturations", saturations);

      saveJSONObject(json, filepath);
      println("Settings saved to: " + filepath);
    } catch (Exception e) {
      println("Error saving settings: " + e.getMessage());
    }
  }

  // Apply settings to all dishes
  void applyToAllDishes(DishSpot[] dishes) {
    for (int i = 0; i < min(dishes.length, 12); i++) {
      dishes[i].setState(dishStates[i]);
      dishes[i].setShape(dishShapes[i]);
      dishes[i].setSymbolColor(dishColors[i]);
      dishes[i].setStrokeWidth(dishWidths[i]);
      dishes[i].setLightnessLevel(dishLightness[i]);
      dishes[i].setHueOffset(dishHueOffsets[i]);
      dishes[i].setSaturationPct(dishSaturations[i]);
      // Reset state after setting properties (setShape etc. force STATE_SYMBOL)
      dishes[i].setState(dishStates[i]);
      dishes[i].setEnabled(dishEnabled[i] != 0);
    }
  }

  // Save settings from all dishes
  void saveFromDishes(DishSpot[] dishes) {
    for (int i = 0; i < min(dishes.length, 12); i++) {
      dishStates[i]     = dishes[i].getState();
      dishShapes[i]     = dishes[i].getShape();
      dishColors[i]     = dishes[i].getSymbolColor();
      dishWidths[i]     = dishes[i].getStrokeWidth();
      dishLightness[i]  = dishes[i].getLightnessLevel();
      dishHueOffsets[i]  = dishes[i].getHueOffset();
      dishSaturations[i] = dishes[i].getSaturationPct();
      dishEnabled[i]    = dishes[i].isEnabled() ? 1 : 0;
    }
    save();
  }
}
