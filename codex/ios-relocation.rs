use std::path::{Component, Path, PathBuf};

/// Relocate only SQLite's selected physical history, retaining its immutable identity.
pub async fn relocate_selected_rollout(
    state: &codex_state::StateRuntime,
    current_home: &Path,
    thread_id: codex_protocol::ThreadId,
    selected: &Path,
) -> std::io::Result<PathBuf> {
    use std::io;
    let Some(destination) = selected_rollout_destination(selected, current_home) else {
        return Ok(selected.to_path_buf());
    };
    let Some(destination) = crate::compression::existing_rollout_path(&destination).await else {
        return Ok(selected.to_path_buf());
    };
    let home = tokio::fs::canonicalize(current_home).await?;
    let resolved = tokio::fs::canonicalize(&destination).await?;
    if !resolved.starts_with(&home)
        || crate::read_session_meta_line(&destination).await?.meta.id != thread_id
    {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "Relocated rollout does not match the selected thread",
        ));
    }
    let replaced = state
        .replace_rollout_path_if_current(thread_id, selected, &destination)
        .await
        .map_err(io::Error::other)?;
    if !replaced
        && state
            .find_rollout_path_by_id(thread_id, None)
            .await
            .map_err(io::Error::other)?
            .as_ref()
            != Some(&destination)
    {
        return Err(io::Error::new(
            io::ErrorKind::WouldBlock,
            "Selected rollout changed during relocation; retry resume",
        ));
    }
    Ok(destination)
}

/// Propose the same selected rollout under the current home, never another branch.
/// The caller must verify the file's thread id before committing the path swap.
pub fn selected_rollout_destination(selected: &Path, current_home: &Path) -> Option<PathBuf> {
    if !selected.is_absolute() || !current_home.is_absolute() {
        return None;
    }
    if selected
        .components()
        .chain(current_home.components())
        .any(|part| part == Component::ParentDir)
    {
        return None;
    }
    for root in selected.ancestors() {
        if root.file_name()? != "codex" || root.parent()?.file_name()? != "Library" {
            continue;
        }
        let container = root.parent()?.parent()?;
        if !apple_container(container) {
            continue;
        }
        let relative = selected.strip_prefix(root).ok()?;
        let mut parts = relative.components();
        let subdir = parts.next()?.as_os_str();
        if (subdir != "sessions" && subdir != "archived_sessions") || parts.next().is_none() {
            return None;
        }
        let destination = current_home.join(relative);
        return (destination != selected).then_some(destination);
    }
    None
}

fn apple_container(root: &Path) -> bool {
    fn uuid(value: &str) -> bool {
        value.len() == 36 && uuid::Uuid::parse_str(value).is_ok()
    }
    fn tail(value: &str) -> bool {
        let parts: Vec<_> = value.split('/').collect();
        matches!(parts.as_slice(), ["Data", "Application", id] | ["Shared", "AppGroup", id] if uuid(id))
    }
    let Some(value) = root.to_str() else {
        return false;
    };
    for prefix in ["/private/var/mobile/Containers/", "/var/mobile/Containers/"] {
        if let Some(relative) = value.strip_prefix(prefix) {
            return tail(relative);
        }
    }
    if let Some((_, relative)) = value.split_once("/Library/Developer/CoreSimulator/Devices/")
        && let Some((device, relative)) = relative.split_once("/data/Containers/")
    {
        return uuid(device) && tail(relative);
    }
    false
}

/// Relocate an unavailable saved directory beneath the current application home.
/// An accessible original always wins; a missing destination never replaces it.
#[cfg(unix)]
pub fn restored_workspace(saved: &Path, current_home: &Path) -> PathBuf {
    use std::os::unix::ffi::OsStrExt;
    fn accessible(path: &Path) -> bool {
        unsafe extern "C" {
            fn access(path: *const std::ffi::c_char, mode: std::ffi::c_int) -> std::ffi::c_int;
        }
        let Ok(path_c) = std::ffi::CString::new(path.as_os_str().as_bytes()) else {
            return false;
        };
        // POSIX R_OK | X_OK, require readable and searchable saved directories.
        path.is_dir() && unsafe { access(path_c.as_ptr(), 4 | 1) == 0 }
    }
    if accessible(saved)
        || !saved.is_absolute()
        || saved.components().any(|part| part == Component::ParentDir)
    {
        return saved.to_path_buf();
    }
    let Ok(home) = current_home.canonicalize() else {
        return saved.to_path_buf();
    };
    if !apple_container(&home)
        || !home
            .parent()
            .is_some_and(|parent| parent.ends_with("Containers/Data/Application"))
    {
        return saved.to_path_buf();
    }
    for old_home in saved.ancestors().filter(|root| apple_container(root)) {
        // Use the same application-container parent, including /private aliases.
        if old_home
            .parent()
            .and_then(|parent| parent.canonicalize().ok())
            != home.parent().map(Path::to_path_buf)
        {
            continue;
        }
        let Ok(relative) = saved.strip_prefix(old_home) else {
            continue;
        };
        let destination = home.join(relative);
        if accessible(&destination)
            && let Ok(resolved) = destination.canonicalize()
            && resolved.starts_with(&home)
        {
            return resolved;
        }
    }
    saved.to_path_buf()
}

#[cfg(not(unix))]
pub fn restored_workspace(saved: &Path, _current_home: &Path) -> PathBuf {
    saved.to_path_buf()
}

/// Restore runtime directories in memory; retain immutable history references and permissions.
#[cfg(any(target_os = "ios", test))]
pub fn restore_item_paths(item: &mut codex_history::RolloutItem, current_home: &Path) {
    use codex_history::RolloutItem;
    use codex_protocol::protocol::EventMsg;
    use codex_utils_absolute_path::AbsolutePathBuf;

    fn restore_absolute(saved: &mut AbsolutePathBuf, home: &Path) {
        let restored = restored_workspace(saved.as_path(), home);
        // A canonical destination is absolute; retain the original if conversion fails.
        if let Ok(restored) = AbsolutePathBuf::from_absolute_path(restored) {
            *saved = restored;
        }
    }
    match item {
        RolloutItem::SessionMeta(line) => {
            line.meta.cwd = restored_workspace(&line.meta.cwd, current_home);
            if let Some(roots) = &mut line.meta.runtime_workspace_roots {
                for root in roots {
                    *root = restored_workspace(root, current_home);
                }
            }
        }
        RolloutItem::TurnContext(context) => {
            restore_absolute(&mut context.cwd, current_home);
            if let Some(roots) = &mut context.workspace_roots {
                for root in roots {
                    restore_absolute(root, current_home);
                }
            }
        }
        RolloutItem::EventMsg(EventMsg::ThreadSettingsApplied(event)) => {
            restore_absolute(&mut event.thread_settings.cwd, current_home);
            if let Some(roots) = &mut event.thread_settings.runtime_workspace_roots {
                for root in roots {
                    restore_absolute(root, current_home);
                }
            }
        }
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const UUID: &str = "5FDA8036-0000-4000-8000-000000000001";
    const FILE: &str = "sessions/2026/10/16/rollout-selected.jsonl";

    #[test]
    fn private_home_copy_keeps_the_exact_selected_filename() {
        let selected = PathBuf::from(format!(
            "/private/var/mobile/Containers/Data/Application/{UUID}/Library/codex/{FILE}"
        ));
        let home =
            Path::new("/private/var/mobile/Containers/Shared/AppGroup/current/Library/codex");
        assert_eq!(
            selected_rollout_destination(&selected, home),
            Some(home.join(FILE))
        );
    }

    #[test]
    fn shared_group_relocation_preserves_archived_compressed_selection() {
        let selected = PathBuf::from(format!(
            "/var/mobile/Containers/Shared/AppGroup/{UUID}/Library/codex/archived_sessions/rollout-reverted.jsonl.zst"
        ));
        assert_eq!(
            selected_rollout_destination(&selected, Path::new("/new/home")),
            Some(PathBuf::from(
                "/new/home/archived_sessions/rollout-reverted.jsonl.zst"
            ))
        );
    }

    #[test]
    fn simulator_uses_the_same_mapping() {
        let selected = PathBuf::from(format!(
            "/Users/test/Library/Developer/CoreSimulator/Devices/{UUID}/data/Containers/Data/Application/{UUID}/Library/codex/{FILE}"
        ));
        assert_eq!(
            selected_rollout_destination(&selected, Path::new("/new/home")),
            Some(Path::new("/new/home").join(FILE))
        );
    }

    #[test]
    fn unrelated_or_unsafe_paths_are_not_relocated() {
        let root = format!("/private/var/mobile/Containers/Data/Application/{UUID}/Library/codex");
        for selected in [
            format!("/external/Library/codex/{FILE}"),
            format!("{root}/../other/{FILE}"),
            format!("{root}/sessions/../../outside.jsonl"),
            format!("{root}/logs/log.jsonl"),
            format!("{root}/sessions-extra/file.jsonl"),
            format!("{root}/sessions"),
            format!("relative/{FILE}"),
            format!(
                "/private/var/mobile/Containers/Data/Application/not-a-uuid/Library/codex/{FILE}"
            ),
        ] {
            assert_eq!(
                selected_rollout_destination(Path::new(&selected), Path::new("/new/home")),
                None,
                "{selected}"
            );
        }
    }

    #[test]
    fn current_home_and_relative_destination_are_unchanged() {
        let home = PathBuf::from(format!(
            "/var/mobile/Containers/Data/Application/{UUID}/Library/codex"
        ));
        assert_eq!(selected_rollout_destination(&home.join(FILE), &home), None);
        assert_eq!(
            selected_rollout_destination(&home.join(FILE), Path::new("relative")),
            None
        );
    }
    #[test]
    fn restored_workspace_requires_an_accessible_destination_and_retains_external_roots() {
        let temp = tempfile::tempdir().unwrap();
        let parent = temp.path().join(format!(
            "Library/Developer/CoreSimulator/Devices/{UUID}/data/Containers/Data/Application"
        ));
        let old_home = parent.join(UUID);
        let current_home = parent.join("8DC29F9E-0000-4000-8000-000000000002");
        let old = old_home.join("Documents/project");
        let current = current_home.join("Documents/project");
        std::fs::create_dir_all(&current).unwrap();
        assert_eq!(
            restored_workspace(&old, &current_home),
            current.canonicalize().unwrap()
        );
        let mut item =
            codex_history::RolloutItem::SessionMeta(codex_protocol::protocol::SessionMetaLine {
                meta: codex_protocol::protocol::SessionMeta {
                    cwd: old.clone(),
                    runtime_workspace_roots: Some(vec![
                        old.clone(),
                        temp.path().join("external-unavailable"),
                    ]),
                    originator: "retained-originator".into(),
                    history_base: Some(codex_protocol::protocol::HistoryPosition {
                        thread_id: codex_protocol::ThreadId::from_string(UUID).unwrap(),
                        end_ordinal_exclusive: 17,
                        end_byte_offset: 1234,
                    }),
                    ..Default::default()
                },
                git: None,
            });
        restore_item_paths(&mut item, &current_home);
        let codex_history::RolloutItem::SessionMeta(line) = item else {
            panic!("wrong item kind")
        };
        assert_eq!(line.meta.cwd, current.canonicalize().unwrap());
        assert_eq!(
            line.meta.runtime_workspace_roots.unwrap(),
            vec![
                current.canonicalize().unwrap(),
                temp.path().join("external-unavailable")
            ]
        );
        assert_eq!(line.meta.originator, "retained-originator");
        let base = line.meta.history_base.unwrap();
        assert_eq!(base.thread_id.to_string(), UUID.to_lowercase());
        assert_eq!(base.end_ordinal_exclusive, 17);
        assert_eq!(base.end_byte_offset, 1234);
        let mut context: codex_history::RolloutItem = serde_json::from_value(serde_json::json!({
            "type": "turn_context",
            "payload": {
                "cwd": old,
                "workspace_roots": [old],
                "approval_policy": "never",
                "sandbox_policy": {"type": "danger-full-access"},
                "model": "fixture",
                "summary": "auto"
            }
        }))
        .unwrap();
        restore_item_paths(&mut context, &current_home);
        let codex_history::RolloutItem::TurnContext(context) = context else {
            panic!("wrong item kind")
        };
        assert_eq!(context.cwd.as_path(), current.canonicalize().unwrap());
        assert_eq!(
            context.workspace_roots.unwrap()[0].as_path(),
            current.canonicalize().unwrap()
        );
        let missing = old_home.join("Documents/missing");
        assert_eq!(restored_workspace(&missing, &current_home), missing);
        std::fs::create_dir_all(&old).unwrap();
        assert_eq!(restored_workspace(&old, &current_home), old);
        let external = temp.path().join("bookmarked-vault");
        std::fs::create_dir(&external).unwrap();
        assert_eq!(restored_workspace(&external, &current_home), external);
        let outside = temp.path().join("outside");
        std::fs::create_dir(&outside).unwrap();
        std::os::unix::fs::symlink(&outside, current_home.join("Documents/link")).unwrap();
        let link = old_home.join("Documents/link");
        assert_eq!(restored_workspace(&link, &current_home), link);
    }
}
