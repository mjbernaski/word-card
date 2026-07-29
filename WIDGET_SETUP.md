# WordCardWidget — setup on the Xcode machine

These steps get the new random-card widget building and running after pulling the widget commit.

## 1. Pull

```sh
cd word-card    # or wherever you keep it
git pull
```

## 2. Open the project

```sh
open WordCard.xcodeproj
```

If Xcode complains the project is corrupt, stop and report what it said. To fall back to before the widget commit:

```sh
git reset --hard 58f7778
```

If it opens cleanly you should see a new **WordCardWidget** target in the target list and a new **WordCardWidget** group in the project navigator with 5 files.

## 3. Register the App Group (Apple Developer portal)

Go to <https://developer.apple.com/account> → Identifiers → **App Groups** → **+** → register:

- **Description:** Word Card Shared
- **Identifier:** `group.mjbernaski.wordcard.app`

## 4. Attach the App Group to both targets in Xcode

For **each** target (WordCard *and* WordCardWidget):

- Select the target → **Signing & Capabilities** tab
- Click **+ Capability** → **App Groups** (skip if it's already listed)
- Check `group.mjbernaski.wordcard.app`
- If Xcode shows a yellow **Fix** button next to signing, click it — it'll provision the App Group on both App IDs

## 5. Build & run the host app once

Pick the **WordCard** scheme and build for iOS (or Mac). Running the app once causes `WidgetSnapshotService` to write the JSON snapshot into the App Group container.

## 6. Add the widget

- **iOS:** long-press home screen → **+** → search "Word Card" → pick a size → Add
- **macOS:** right-click desktop → **Edit Widgets** → search "Word Card"
- **visionOS:** Widgets app → search "Word Card"

Tap/click it — it should open the host app.

## Troubleshooting

- **Project won't open:** `git reset --hard 58f7778` puts you back to before the widget commit; report what Xcode said.
- **Widget shows "Open Word Card to add a card" forever:** the snapshot file isn't being read. Double-check the App Group identifier is *exactly* `group.mjbernaski.wordcard.app` on both targets and that you've launched the host app at least once.
- **Code-sign error mentioning the widget bundle id:** `mjbernaski.wordcard.app.WordCardWidget` will be auto-registered the first time Xcode signs it; just hit Build again.
