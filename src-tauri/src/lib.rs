use std::fs;
use std::path::PathBuf;
use tauri::Manager;

fn workspace_path(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_data_dir()
        .map(|directory| directory.join("workspace.json"))
        .map_err(|error| error.to_string())
}

#[tauri::command]
fn load_workspace(app: tauri::AppHandle) -> Result<Option<String>, String> {
    let path = workspace_path(&app)?;
    if !path.exists() {
        return Ok(None);
    }
    fs::read_to_string(path)
        .map(Some)
        .map_err(|error| error.to_string())
}

#[tauri::command]
fn save_workspace(app: tauri::AppHandle, contents: String) -> Result<(), String> {
    let path = workspace_path(&app)?;
    let directory = path
        .parent()
        .ok_or_else(|| "Cannot determine app data directory".to_string())?;
    fs::create_dir_all(directory).map_err(|error| error.to_string())?;

    let temporary_path = path.with_extension("json.tmp");
    fs::write(&temporary_path, contents).map_err(|error| error.to_string())?;
    fs::rename(temporary_path, path).map_err(|error| error.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![load_workspace, save_workspace])
        .run(tauri::generate_context!())
        .expect("error while running application");
}
