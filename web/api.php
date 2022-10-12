<?php
ini_set('display_errors', '1');
ini_set('display_startup_errors',1);
error_reporting(-1);

define('SNAPSHOTS_FOLDER', "./snapshots/");
//define('EMPTY_RESULT', array());

define("QUERY_REGEXP",        0);
define("QUERY_BIGGER_EQUAL",  1);
define("QUERY_SMALLER_EQUAL", 2);
define("QUERY_LIST_INCLUDE",  3);
define("QUERY_LIST_EXCLUDE",  4);

$QUERY_CRITERIA = array( );

function add_criteria($query_label, $type=QUERY_REGEXP, $info_label=NULL) {
  global $QUERY_CRITERIA;
  if (!$info_label)
    $info_label = $query_label;
  $QUERY_CRITERIA[$query_label] = array(
    'label' => $info_label,
    'type' => $type
  );
}

add_criteria("uid");
add_criteria("node_name");
add_criteria("session_name");
add_criteria("time_source");
add_criteria("time_zone");
add_criteria("from_time", QUERY_SMALLER_EQUAL, "unix_time");
add_criteria("to_time", QUERY_BIGGER_EQUAL, "unix_time");
add_criteria("from_duration", QUERY_SMALLER_EQUAL, "duration");
add_criteria("to_duration", QUERY_BIGGER_EQUAL, "duration");
add_criteria("from_time", QUERY_SMALLER_EQUAL, "unix_time");
add_criteria("tags_include", QUERY_LIST_INCLUDE, "tags");
add_criteria("tags_exclude", QUERY_LIST_EXCLUDE, "tags");

function query_match_one($query_item, $info_item, $type) {
  if ($type == QUERY_REGEXP)
    return preg_match_full($query_item, $info_item);
  elseif ($type == QUERY_SMALLER_EQUAL)
    return $query_item <= $info_item;
  elseif ($type == QUERY_BIGGER_EQUAL)
    return $query_item >= $info_item;
  elseif ($type == QUERY_LIST_INCLUDE)
    return empty(array_diff($query_item, $info_item));
  elseif ($type == QUERY_LIST_EXCLUDE)
    return empty(array_intersect($query_item, $info_item));
  else
    return false;
}

function query_match(&$query, &$info, &$error) {
  global $QUERY_CRITERIA;
  $keys = array_keys($QUERY_CRITERIA);
  foreach ($keys as $key) {
    if (array_key_exists($key, $query)) {
      $criteria = $QUERY_CRITERIA[$key];
      $info_key = $criteria['label'];
      if (!array_key_exists($info_key, $info)) {
        $error[] = "Criteria label '$info_key' does not exist for item '" . $info->uid ."'.";
        return false;
      } else if (!query_match_one($query->$key, $info->$info_key, $criteria['type']))
        return false;
    }
  }
  return true;
}

// Collects and returns data according to query.
function get_data($query, &$error) {
  $data = array();

  // Run through all directories.
  foreach (glob(SNAPSHOTS_FOLDER . "/*", GLOB_ONLYDIR) as $dir) {
    // Get meta information.
    $info = json_decode(file_get_contents("$dir/info.json"));
    // Extract other information.
    $images = get_images($dir);
    $info->n_images = count($images);
    $last_image_info = end($images);
    $info->duration = $last_image_info['time'];
    // Include tags in info.
    $info->tags = get_tags($info->uid, $error);
    // Check meta information according to query.
    if (query_match($query, $info, $error)) {
      $data[] = array(
        "info" => $info,
        "images" => $images,
      );
    }
  }

  return $data;
}

function get_tags($uids, $error) {
  if (!is_array($uids)) {
    $tags_file_name = SNAPSHOTS_FOLDER . "/$uids/tags.json";
    if (file_exists($tags_file_name)) {
      return json_decode(file_get_contents($tags_file_name));
    } else {
      return array();
    }
  } else {
    $results = array();
    foreach ($uids as $uid) {
      $results[$uid] = get_tags($uid, $error);
    }
    return $results;
  }
}

function add_tags($uids, $tags, &$error) {
  // Gather current tags.
  $current_tags = get_tags($uids, $error);
  if (!is_array($uids))
    $uids = array($uids);
  // Add tags.
  foreach ($uids as $uid) {
    set_tags($uid, array_merge($current_tags[$uid], $tags), $error);
  }
  return array();
}

function remove_tags($uids, $tags, &$error) {
  // Gather current tags.
  $current_tags = get_tags($uids, $error);
  if (!is_array($uids))
    $uids = array($uids);
  // Remove tags.
  foreach ($uids as $uid) {
    set_tags($uid, array_diff($current_tags[$uid], $tags), $error);
  }
  return array();
}

function set_tags($uids, $tags, &$error) {
  if (!is_array($uids)) {
    $tags_file_name = SNAPSHOTS_FOLDER . "/$uids/tags.json";
    if (!file_put_contents($tags_file_name, json_encode($tags))) {
      $error[] = "Cannot open file '$tags_file_name' to edit tags.";
    }
  } else {
    foreach ($uids as $uid) {
      set_tags($uid, $tags, $error);
    }
  }

  return array();
}

// Returns images of a certain type in given directory.
function get_images($dir) {
  $images = array();
  foreach (glob("$dir/snapshot_*.png") as $img) {
    // Append image info to images array.
    $image_info = get_image_info($img);
    if (!isset($images[$image_info->step])) {
      $images[(int)$image_info->step] = array('time' => $image_info->time);
    }
    $images[(int)$image_info->step][$image_info->type] = $image_info->path;
  }

  // Re-index array.
  return array_values($images);
}

function get_image_info($img) {
  if (preg_match("/snapshot_(?<step>\d+)_0*(?<time>\d+)_(?<type>.+).png/", $img, $matches)) {
    $image_info = new stdClass;
    $image_info->step = ((int)$matches['step']);
    $image_info->time = ((int)$matches['time']) / 1000.0;
    $type = $matches['type'];
    if ($type == "raw_0trn") $type = "transformed";
    elseif ($type == "raw_1fil") $type = "filtered";
    elseif ($type == "raw_2res") $type = "resized";
    elseif ($type == "raw_3ann") $type = "ann";
    $image_info->type = $type;
    $image_info->path = $img;
    return $image_info;
  }
  else
    return false;
}

// Shortcut funciton to match exactly one full line.
function preg_match_full($regexp, $value) {
  $regexp = str_replace("/", "\/", $regexp);
  return preg_match("/^".$regexp."$/", $value);
}

function download($uids, &$error) {
  $zipFilename = "xeno-archive.zip";

  // Initialize archive object
  $zip = new ZipArchive();
  $zip->open($zipFilename, ZipArchive::CREATE | ZipArchive::OVERWRITE);

  if (!is_array($uids))
    $uids = array( $uids );
  foreach ($uids as $uid) {
    // Get real path for our folder
    $rootPath = realpath(SNAPSHOTS_FOLDER . "/$uid");

    // Create recursive directory iterator
    /** @var SplFileInfo[] $files */
    $files = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($rootPath),
        RecursiveIteratorIterator::LEAVES_ONLY
    );

    foreach ($files as $name => $file)
    {
        // Skip directories (they would be added automatically)
        if (!$file->isDir())
        {
            // Get real and relative path for current file
            $filePath = $file->getRealPath();
            $relativePath = "$uid/" . substr($filePath, strlen($rootPath) + 1);

            // Add current file to archive
            $zip->addFile($filePath, $relativePath);
        }
    }
  }

  // Zip archive will be created only after closing object
  $zip->close();

  return $zipFilename;
  //
  // header('Content-Type: application/zip');
  // header("Content-Disposition: attachment; filename='$zipFilename'");
  // header('Content-Length: ' . filesize($zipFilename));
  // header("Location: $zipFilename");
}

function get_option(&$get, $option, &$error, $json=true, $default=false) {
  if (array_key_exists($option, $get)) {
    $result = $get[$option];
  }
  else {
    $error[] = "Option '$option' is mnissing from command.";
    $result = $default;
  }
  return ($json ? json_decode($result) : $result);
}

function run(&$get, $json=true) {
  $error = [];
  $action = get_option($get, 'action', $error, false);

  if ($action == 'query') {
    $query = get_option($get, 'q', $error);

    $result = get_data($query, $error);
  }
  else if ($action == 'update_tags') {
    $operation = get_option($get, 'operation', $error, false, 'set');
    $tags = get_option($get, 'tags', $error, true, array());
    $uids = get_option($get, 'uids', $error, true, array());
    if ($operation == 'set')
      $result = set_tags($uids, $tags, $error);
    elseif ($operation == 'add')
      $result = add_tags($uids, $tags, $error);
    elseif ($operation == 'remove')
      $result = remove_tags($uids, $tags, $error);
    else {
      $error[] = "Unrecognized operation: '$operation'.";
      $result = array();
    }
  }
  else if ($action == 'get_tags') {
    $uids = get_option($get, 'uids', $error, true, array());
    $result = get_tags($uids, $error);
  }
  else if ($action == "download") {
    $uids = get_option($get, 'uids', $error, true, array());
    $result = array('zipfile' => download($uids, $error));
  }
  else {
    $error[] = "Unrecognized action: '$action'.";
    $result = array();
  }

  $return = array(
    'error' => (count($error) > 0 ? $error : false),
    'result' => $result
  );

  if ($json)
    print(json_encode($return));
  else
    print_r($return);
}

// Run it!
run($_GET, isset($_GET['json']) ? $_GET['json'] == 'true' : true);
?>
