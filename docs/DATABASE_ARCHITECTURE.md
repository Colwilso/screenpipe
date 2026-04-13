# Screenpipe Database Architecture Overview

## Context

This document provides a comprehensive map of the screenpipe SQLite database schema:
- Which tables are "real" vs virtual (FTS5 search indexes)
- Why some columns appear blank
- Which tables to focus on for analysis

Based on 70+ migrations (Jul 2024 - Mar 2026) and current Rust type definitions.

## Quick Start

**Verify your database status:**
```bash
./scripts/verify_db.sh
```

This will show you what data is being captured, storage breakdown, and recent activity.

## Database Architecture Map

### Primary Data Tables (Where the data lives)

**Screen Capture:**
- **`frames`** - Every captured screen frame with metadata (app_name, window_name, browser_url, full_text, accessibility_tree_json, timestamp)
- **`video_chunks`** - Raw .mp4 files (legacy continuous recording mode)
- **`ocr_text`** - Per-frame OCR text with word-level bounding boxes (for rendering highlights)
- **`elements`** - Hierarchical screen structure (OCR + accessibility tree nodes with bounds)

**Audio Capture:**
- **`audio_chunks`** - Raw .wav/.m4a files
- **`audio_transcriptions`** - Speech-to-text segments with timestamps and speaker IDs

**User Input:**
- **`ui_events`** - Keyboard, mouse, clipboard, app-switch events with element context

**Speaker Identity:**
- **`speakers`** - Speaker names/metadata
- **`speaker_embeddings`** - 512-dimensional voice fingerprints for cross-device matching

**Organization:**
- **`memories`** - Persistent facts/preferences/insights (used by AI agents)
- **`meetings`** - Detected meetings with attendees and notes
- **`tags`**, **`vision_tags`**, **`audio_tags`** - User-applied tags

**Pipes:**
- **`pipe_executions`** - AI agent run history
- **`pipe_scheduler_state`** - Scheduling persistence

### Virtual Tables (FTS5 Search Indexes)

These are SQLite FTS5 full-text search tables - they don't store data, they index text from the main tables:

- **`frames_fts`** - Indexes frames.full_text (primary screen search)
- **`audio_transcriptions_fts`** - Indexes audio_transcriptions.transcription
- **`elements_fts`** - Indexes elements.text (per-UI-element search)
- **`ui_events_fts`** - Indexes ui_events.text_content (typed text search)
- **`memories_fts`** - Indexes memories.content

**How to use them:**
```sql
-- Search all screen content
SELECT * FROM frames_fts WHERE frames_fts MATCH 'search term';

-- Search audio
SELECT * FROM audio_transcriptions_fts WHERE audio_transcriptions_fts MATCH 'meeting notes';
```

The FTS tables automatically stay in sync via SQLite triggers.

## Why Columns Are Blank

### 1. Platform-Specific Features

**`accessibility_text`** / **`accessibility_tree_json`** (frames table):
- **Full on macOS** - Apple Accessibility APIs provide rich text and tree structure
- **Limited on Windows** - UIAutomation available but less comprehensive
- **Limited on Linux** - AT-SPI available but app support varies
- **Will be NULL/empty when:**
  - App doesn't expose accessibility APIs
  - User hasn't granted accessibility permissions
  - Fallback to OCR-only mode

**`browser_url`** (frames table):
- Only populated for browser windows (Chrome, Firefox, Safari)
- Empty for non-browser apps

### 2. Feature-Specific Columns

**`speaker_id`** (audio_transcriptions table):
- NULL when speaker diarization is disabled
- NULL for audio without speech
- Only populated after voice embedding analysis completes

**`snapshot_path`** (frames table):
- Only populated in event-driven capture mode (new, default)
- NULL for frames from video chunks (legacy continuous recording mode)

**`video_chunk_id`** (frames table):
- NULL for event-driven frames (stored as JPEGs in snapshot_path)
- Only populated for video chunk frames (legacy)

**`segment_start_time`**, **`segment_end_time`** (audio_transcriptions table):
- Exact timestamps within audio chunk (for precise speaker timing)
- May be NULL for simpler transcription engines

### 3. Vestigial/Deprecated Columns

**In `ocr_text` table:**
- `unique_text_lines_24hr`, `unique_text_lines_1hr`, `unique_text_lines_1m` - Old diff tracking (no longer used)
- `diff_vs_previous_frame_by_line` - Deprecated
- `raw_data_output_from_ocr` - Legacy Tesseract TSV output (rarely used)

**Why kept?** - `ocr_text.text_json` still used for word-level bounding boxes when rendering search highlights. Rest is legacy.

**Search now uses:** `frames.full_text` → `frames_fts` (consolidated text from all sources)

### 4. Cloud Sync Columns

**`sync_id`**, **`machine_id`**, **`synced_at`** (on frames, audio_chunks, audio_transcriptions, video_chunks, ui_events):
- NULL when cloud sync is disabled (default)
- Only populated when user enables cloud sync feature

## Which Tables to Focus On

### For Screen Activity Analysis
**Primary table:** `frames`
```sql
-- See what apps/windows you used with timestamps
SELECT timestamp, app_name, window_name, browser_url
FROM frames
ORDER BY timestamp DESC
LIMIT 100;

-- Full-text search all screen content
SELECT * FROM frames_fts WHERE frames_fts MATCH 'search query';

-- Get accessibility tree for a specific frame
SELECT accessibility_tree_json FROM frames WHERE id = ?;
```

### For Audio/Transcription Analysis
**Primary table:** `audio_transcriptions`
```sql
-- See what was said and when
SELECT timestamp, transcription, device, is_input_device
FROM audio_transcriptions
ORDER BY timestamp DESC
LIMIT 100;

-- Search transcriptions
SELECT * FROM audio_transcriptions_fts WHERE audio_transcriptions_fts MATCH 'meeting topic';

-- Group by speaker (if diarization enabled)
SELECT speaker_id, GROUP_CONCAT(transcription, ' ') as full_transcript
FROM audio_transcriptions
WHERE speaker_id IS NOT NULL
GROUP BY speaker_id;
```

### For User Input Analysis
**Primary table:** `ui_events`
```sql
-- See what you typed, clicked, which apps you switched to
SELECT timestamp, event_type, app_name, window_title, text_content
FROM ui_events
ORDER BY timestamp DESC
LIMIT 100;

-- Search typed text
SELECT * FROM ui_events_fts WHERE ui_events_fts MATCH 'typed text';
```

### For Hierarchical Screen Structure
**Primary table:** `elements`
```sql
-- Get all UI elements from a frame with hierarchy
SELECT id, parent_id, depth, role, text, source
FROM elements
WHERE frame_id = ?
ORDER BY sort_order;

-- Search for specific UI elements
SELECT * FROM elements_fts WHERE elements_fts MATCH 'Submit button';
```

### For AI-Generated Insights
**Primary tables:** `memories`, `meetings`
```sql
-- See persistent facts/preferences stored by agents
SELECT content, source, importance, created_at FROM memories ORDER BY importance DESC;

-- See detected meetings
SELECT meeting_start, title, attendees FROM meetings ORDER BY meeting_start DESC;
```

## Key Relationships

```
video_chunks.id ←─ frames.video_chunk_id (legacy mode)
audio_chunks.id ←─ audio_transcriptions.audio_chunk_id
speakers.id ←─ speaker_embeddings.speaker_id
speakers.id ←─ audio_transcriptions.speaker_id
frames.id ←─ ocr_text.frame_id
frames.id ←─ elements.frame_id
frames.id ←─ ui_events.frame_id (correlate input with screen)
frames.id ←─ memories.frame_id (link memory to screenshot)
tags.id ←─ vision_tags.tag_id / audio_tags.tag_id
```

## Data Flow Summary

1. **Screen capture** → `frames` table → `frames_fts` index (searchable)
2. **Audio capture** → `audio_chunks` → `audio_transcriptions` → `audio_transcriptions_fts` (searchable)
3. **User input** → `ui_events` → `ui_events_fts` (searchable)
4. **OCR** → `ocr_text` (word boxes) + merged into `frames.full_text`
5. **Accessibility** → `frames.accessibility_text` + `frames.accessibility_tree_json` + `elements` (structured tree)
6. **AI agents/pipes** → read from FTS tables → write to `memories` table

## Schema Evolution Notes

- **Mar 2026**: Unified 6 fragmented FTS tables into `frames_fts` + per-content-type indexes. Dropped `accessibility` table (data moved to `frames`).
- **Feb 2026**: Added event-driven capture (snapshot_path), added ui_events table.
- **Nov 2024**: Added speaker diarization (speaker_id, speaker_embeddings).
- **Jul 2024**: Initial schema with video_chunks, frames, audio_chunks, audio_transcriptions.

## Verification Queries

Query the main tables to see what data is being captured:

```bash
# Screen capture status
sqlite3 ~/.screenpipe/db.sqlite "SELECT COUNT(*), MIN(timestamp), MAX(timestamp) FROM frames;"

# Audio capture status
sqlite3 ~/.screenpipe/db.sqlite "SELECT COUNT(*), MIN(timestamp), MAX(timestamp) FROM audio_transcriptions;"

# Check what's being populated
sqlite3 ~/.screenpipe/db.sqlite "SELECT
  COUNT(*) as total,
  COUNT(accessibility_text) as has_accessibility,
  COUNT(snapshot_path) as has_snapshot,
  COUNT(browser_url) as has_url
FROM frames;"
```

## Usage Tips

1. **Start with FTS tables for search** - They're optimized for full-text search and are the primary interface for finding content.
2. **Use frames table for structured analysis** - Join with elements/ocr_text for detailed per-frame data.
3. **Check platform-specific columns** - accessibility_text/accessibility_tree_json will be richer on macOS than Windows/Linux.
4. **Ignore vestigial columns** - Old diff tracking and OCR output columns are deprecated but kept for backwards compatibility.
5. **Check feature flags** - speaker_id and sync columns only populated when features are enabled.
