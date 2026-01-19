/**
 * Settings
 *
 * Handles JSON configuration persistence for EuglenaLightTable.
 * Saves state, shape, color, and width for each dish.
 */
class Settings {
  String filepath;

  // Saved settings for each dish
  int[] dishStates = new int[6];
  int[] dishShapes = new int[6];
  int[] dishColors = new int[6];
  int[] dishWidths = new int[6];

  Settings(String filepath) {
    this.filepath = filepath;
    // Initialize to defaults
    for (int i = 0; i < 6; i++) {
      dishStates[i] = DishSpot.STATE_WHITE;
      dishShapes[i] = DishSpot.SHAPE_X;
      dishColors[i] = DishSpot.COLOR_MAGENTA;
      dishWidths[i] = DishSpot.WIDTH_THIN;
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
        for (int i = 0; i < min(arr.size(), 6); i++) {
          dishStates[i] = arr.getInt(i);
        }
      }

      // Load dish shapes
      if (json.hasKey("dishShapes")) {
        JSONArray arr = json.getJSONArray("dishShapes");
        for (int i = 0; i < min(arr.size(), 6); i++) {
          dishShapes[i] = arr.getInt(i);
        }
      }

      // Load dish colors
      if (json.hasKey("dishColors")) {
        JSONArray arr = json.getJSONArray("dishColors");
        for (int i = 0; i < min(arr.size(), 6); i++) {
          dishColors[i] = arr.getInt(i);
        }
      }

      // Load dish widths
      if (json.hasKey("dishWidths")) {
        JSONArray arr = json.getJSONArray("dishWidths");
        for (int i = 0; i < min(arr.size(), 6); i++) {
          dishWidths[i] = arr.getInt(i);
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
      for (int i = 0; i < 6; i++) {
        states.setInt(i, dishStates[i]);
      }
      json.setJSONArray("dishStates", states);

      // Save dish shapes
      JSONArray shapes = new JSONArray();
      for (int i = 0; i < 6; i++) {
        shapes.setInt(i, dishShapes[i]);
      }
      json.setJSONArray("dishShapes", shapes);

      // Save dish colors
      JSONArray colors = new JSONArray();
      for (int i = 0; i < 6; i++) {
        colors.setInt(i, dishColors[i]);
      }
      json.setJSONArray("dishColors", colors);

      // Save dish widths
      JSONArray widths = new JSONArray();
      for (int i = 0; i < 6; i++) {
        widths.setInt(i, dishWidths[i]);
      }
      json.setJSONArray("dishWidths", widths);

      saveJSONObject(json, filepath);
      println("Settings saved to: " + filepath);
    } catch (Exception e) {
      println("Error saving settings: " + e.getMessage());
    }
  }

  // Apply settings to all dishes
  void applyToAllDishes(DishSpot[] dishes) {
    for (int i = 0; i < min(dishes.length, 6); i++) {
      dishes[i].setState(dishStates[i]);
      dishes[i].setShape(dishShapes[i]);
      dishes[i].setSymbolColor(dishColors[i]);
      dishes[i].setStrokeWidth(dishWidths[i]);
      // Reset state after setting properties (setShape etc. force STATE_SYMBOL)
      dishes[i].setState(dishStates[i]);
    }
  }

  // Save settings from all dishes
  void saveFromDishes(DishSpot[] dishes) {
    for (int i = 0; i < min(dishes.length, 6); i++) {
      dishStates[i] = dishes[i].getState();
      dishShapes[i] = dishes[i].getShape();
      dishColors[i] = dishes[i].getSymbolColor();
      dishWidths[i] = dishes[i].getStrokeWidth();
    }
    save();
  }
}
