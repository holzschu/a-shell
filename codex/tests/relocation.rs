use super::test_support::{test_config, write_session_file_with_history_mode};
use crate::{LocalThreadStore, ReadThreadParams, ThreadStore};
use codex_protocol::ThreadId;
use codex_protocol::protocol::{SessionSource, ThreadHistoryMode};
use codex_state::{StateRuntime, ThreadMetadataBuilder};

#[tokio::test]
async fn ios_relocation_public_read_uses_exact_selected_copy_before_rollback()
-> Result<(), Box<dyn std::error::Error>> {
    let root = tempfile::TempDir::new()?;
    let old = root.path().join("Library/Developer/CoreSimulator/Devices/5FDA8036-0000-4000-8000-000000000001/data/Containers/Data/Application/5FDA8036-0000-4000-8000-000000000002/Library/codex");
    let home = root.path().join("current-home");
    std::fs::create_dir_all(&home)?;
    let id = uuid::Uuid::from_u128(146);
    let thread_id = ThreadId::from_string(&id.to_string())?;
    let old_path = write_session_file_with_history_mode(
        &old,
        "2025-01-03T12-00-00",
        id,
        ThreadHistoryMode::Paginated,
    )?;
    // The selected suffix differs from another rollout with the same thread id.
    let selected = write_session_file_with_history_mode(
        &old,
        "2025-01-03T13-00-00",
        id,
        ThreadHistoryMode::Paginated,
    )?;
    let reverted = selected.with_file_name(format!(
        "rollout-2025-01-03T13-00-00-{}.jsonl",
        uuid::Uuid::from_u128(147)
    ));
    std::fs::rename(&selected, &reverted)?;
    let selected = reverted;
    let relative = selected.strip_prefix(&old)?;
    let destination = home.join(relative);
    std::fs::create_dir_all(destination.parent().unwrap())?;
    std::fs::copy(&selected, &destination)?;
    let alternative = home.join(old_path.strip_prefix(&old)?);
    std::fs::copy(&old_path, &alternative)?;
    let retained_bytes = std::fs::read(&selected)?;
    let config = test_config(&home);
    let db = StateRuntime::init(
        config.sqlite.clone(),
        config.default_model_provider_id.clone(),
    )
    .await?;
    let mut builder = ThreadMetadataBuilder::new(
        thread_id,
        selected.clone(),
        chrono::Utc::now(),
        SessionSource::Cli,
    );
    builder.history_mode = ThreadHistoryMode::Paginated;
    builder.cwd = home.clone();
    db.upsert_thread(&builder.build("test-provider")).await?;
    let store = LocalThreadStore::new(config.clone(), Some(db.clone()));
    let first = store
        .read_thread(ReadThreadParams {
            thread_id,
            include_archived: true,
            include_history: false,
        })
        .await?;
    assert_eq!(first.rollout_path, Some(destination.clone()));
    let reopened = LocalThreadStore::new(config, Some(db));
    let second = reopened
        .read_thread(ReadThreadParams {
            thread_id,
            include_archived: true,
            include_history: false,
        })
        .await?;
    assert_eq!(second.rollout_path, Some(destination.clone()));
    let explicit = reopened
        .read_thread_by_rollout_path(selected.clone(), true, false)
        .await?;
    assert_eq!(explicit.rollout_path, Some(destination));
    assert_eq!(std::fs::read(selected)?, retained_bytes);
    Ok(())
}

#[tokio::test]
async fn ios_relocation_public_filtered_resume_restores_workspace()
-> Result<(), Box<dyn std::error::Error>> {
    if std::env::var_os("CODEX_RELOCATION_CHILD").is_none() {
        let temp = tempfile::TempDir::new()?;
        let parent = temp.path().join("Library/Developer/CoreSimulator/Devices/5FDA8036-0000-4000-8000-000000000001/data/Containers/Data/Application");
        let current_home = parent.join("8DC29F9E-0000-4000-8000-000000000002");
        std::fs::create_dir_all(current_home.join("Documents/project"))?;
        // Fake only the process environment boundary, without global test mutations.
        for mode in ["retained", "removed"] {
            let result = std::process::Command::new(std::env::current_exe()?)
                .args(["--exact", "local::ios_relocation_tests::ios_relocation_public_filtered_resume_restores_workspace", "--nocapture"])
                .env("CODEX_RELOCATION_CHILD", mode)
                .env("HOME", &current_home)
                .status()?;
            assert!(
                result.success(),
                "public workspace relocation child failed: {mode}"
            );
        }
        return Ok(());
    }
    let current_home = std::path::PathBuf::from(std::env::var_os("HOME").unwrap());
    let old_home = current_home
        .parent()
        .unwrap()
        .join("5FDA8036-0000-4000-8000-000000000003");
    let old_workspace = old_home.join("Documents/project");
    let current_workspace = current_home.join("Documents/project").canonicalize()?;
    let old = old_home.join("Library/codex");
    let home = current_home.join("Library/codex");
    std::fs::create_dir_all(&home)?;
    let id = uuid::Uuid::from_u128(149);
    let thread_id = ThreadId::from_string(&id.to_string())?;
    let path = write_session_file_with_history_mode(
        &old,
        "2025-01-03T12-00-00",
        id,
        ThreadHistoryMode::Paginated,
    )?;
    let mut meta: serde_json::Value = serde_json::from_str(std::fs::read_to_string(&path)?.trim())?;
    meta["payload"]["cwd"] = serde_json::json!(old_workspace);
    meta["payload"]["runtime_workspace_roots"] = serde_json::json!([old_workspace]);
    std::fs::write(&path, format!("{meta}\n"))?;
    let destination = home.join(path.strip_prefix(&old)?);
    std::fs::create_dir_all(destination.parent().unwrap())?;
    std::fs::copy(&path, &destination)?;
    let config = test_config(&home);
    let db = StateRuntime::init(
        config.sqlite.clone(),
        config.default_model_provider_id.clone(),
    )
    .await?;
    let mut builder = ThreadMetadataBuilder::new(
        thread_id,
        path.clone(),
        chrono::Utc::now(),
        SessionSource::Cli,
    );
    builder.history_mode = ThreadHistoryMode::Paginated;
    builder.cwd = old_workspace;
    let mut metadata = builder.build("test-provider");
    metadata.preview = Some("relocated history".into());
    metadata.first_user_message = Some("relocated history".into());
    db.upsert_thread(&metadata).await?;
    if std::env::var("CODEX_RELOCATION_CHILD").as_deref() == Ok("removed") {
        std::fs::remove_file(&path)?;
    }
    let store = LocalThreadStore::new(config, Some(db));
    let page = store
        .list_threads(crate::ListThreadsParams {
            page_size: 1,
            cursor: None,
            sort_key: crate::ThreadSortKey::CreatedAt,
            sort_direction: crate::SortDirection::Desc,
            allowed_sources: vec![],
            model_providers: None,
            cwd_filters: Some(vec![current_workspace.clone()]),
            section: None,
            project_id: None,
            archived: false,
            search_term: None,
            relation_filter: None,
            use_state_db_only: true,
        })
        .await?;
    assert_eq!(
        page.items.len(),
        1,
        "resume picker must discover the old cwd"
    );
    assert_eq!(page.items[0].thread_id, thread_id);
    assert_eq!(page.items[0].cwd, current_workspace);
    let resumed = store
        .read_thread(ReadThreadParams {
            thread_id,
            include_archived: true,
            include_history: false,
        })
        .await?;
    assert_eq!(resumed.cwd, current_workspace);
    assert_eq!(resumed.rollout_path, Some(destination));
    Ok(())
}
