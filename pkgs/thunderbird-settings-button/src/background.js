// No WebExtension API opens Thunderbird's Settings (about:preferences is off
// limits to tabs.create), so the click goes through the settingsTab experiment.
messenger.action.onClicked.addListener(() => messenger.settingsTab.open());

// Only on first install, so a position chosen later in Customize sticks.
messenger.runtime.onInstalled.addListener(({ reason }) => {
  if (reason == "install") {
    messenger.settingsTab.placeBeforeSearchBar();
  }
});
