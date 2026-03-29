# Ancient Vision – Artifact Capture Client

Flutter client for capturing archaeological artifact metadata, uploading photos to build 3D models, and querying existing artifacts.

## Features

- **Search Artifacts**
	- Filter by `ArtifactID`, `ProjectID`, `SiteID`, `LocationID`, `InvestigationTypes`, `MaterialTypes`, `CulturalTerms`, and `Keywords`.
	- Optional date ranges for `CoverageDate` and `CreatedTime`.
	- Optional "PictureToMatch" image to find visually similar artifacts.
	- Displays server results including 3D model status, model file path, log file path, and match details.

- **Scan New Artifact**
	- Form to enter artifact metadata: project, site, location, coverage date, investigation types, material types, cultural terms, and keywords.
	- Submits metadata to the backend `add_artifact` endpoint and shows the returned `ArtifactID`.

- **Photo Upload & 3D Model Build**
	- Capture photos using the device camera or select from gallery.
	- Upload one or more images to the backend `upload` endpoint using the `ArtifactID` as folder name.
	- The backend can then run COLMAP to build a 3D model for the artifact.

## Architecture

- **lib/main.dart** – Entry point; creates a shared `ApiService` with a configurable `baseUrl` for your Flask backend and starts the app at the Search Artifacts screen.
- **lib/services/api_service.dart** – All HTTP calls to the backend (`add_artifact`, `upload`, `query_artifacts`).
- **lib/models/**
	- `artifact_metadata.dart` – Request model for `add_artifact`.
	- `artifact_record.dart` – Response model for `query_artifacts` results.
- **lib/screens/**
	- `query_artifacts_screen.dart` – Search page and results list (home screen).
	- `metadata_form_screen.dart` – Scan New Artifact metadata form.
	- `photo_upload_screen.dart` – Photo capture/upload for a given `ArtifactID`.

## Backend Expectations

The client assumes a Flask backend exposing at least:

- `POST /add_artifact` – Accepts JSON metadata and returns `{ "ArtifactID": "..." }` or an error.
- `POST /upload` – Multipart form with fields `folder_name`, `completed`, and file `image` for each photo.
- `POST /query_artifacts` – Accepts `sqlwhere` (and optional image `image`) and returns a JSON object with an `artifacts` array.

Update the `baseUrl` in `lib/main.dart` to point at your running Flask server (for example, a LAN IP when testing from a physical device).

## Running the App

From the project root:

```bash
flutter pub get
flutter run
```

Ensure your backend is running and reachable at the configured `baseUrl` before testing network features.

## Platforms

- Android, iOS, and Web are supported.
- On emulators/devices, remember that `localhost` refers to the device, not your PC. Use `10.0.2.2` for Android emulators or your machine's LAN IP for physical devices and iOS simulators.

