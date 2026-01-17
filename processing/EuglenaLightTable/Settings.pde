/**
 * Settings
 *
 * Handles JSON configuration persistence for EuglenaLightTable.
 */
class Settings {
  String filepath;

  // Saved settings
  int[] dishStates = new int[6];  // State of each dish (0=white, 1=black, 2=X)

  Settings(String filepath) {
    this.filepath = filepath;
    // Initialize to default (all white)
    for (int i = 0; i < 6; i++) {
      dishStates[i] = DishSpot.STATE_WHITE;
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
        JSONArray states = json.getJSONArray("dishStates");
        for (int i = 0; i < min(states.size(), 6); i++) {
          dishStates[i] = states.getInt(i);
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

      saveJSONObject(json, filepath);
      println("Settings saved to: " + filepath);
    } catch (Exception e) {
      println("Error saving settings: " + e.getMessage());
    }
  }
}
