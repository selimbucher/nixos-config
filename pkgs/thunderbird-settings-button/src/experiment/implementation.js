"use strict";

var { ExtensionCommon } = ChromeUtils.importESModule(
  "resource://gre/modules/ExtensionCommon.sys.mjs"
);
var { getState, storeState } = ChromeUtils.importESModule(
  "resource:///modules/CustomizationState.mjs"
);
var { EXTENSION_PREFIX, getDefaultItemIdsForSpace } =
  ChromeUtils.importESModule("resource:///modules/CustomizableItems.sys.mjs");

// Same list ext-browserAction.js uses for allowed_spaces: [].
var SPACES = [
  "mail",
  "addressbook",
  "calendar",
  "tasks",
  "chat",
  "settings",
  "default",
];

var styleSheetService = Cc[
  "@mozilla.org/content/style-sheet-service;1"
].getService(Ci.nsIStyleSheetService);

var settingsTab = class extends ExtensionCommon.ExtensionAPI {
  // Add-on icons can't use context paint, so they can't follow the toolbar's
  // text colour like the built-in buttons do. Swap in Thunderbird's own gear
  // and paint it exactly like theirs (light, dark, inactive window, userChrome).
  // A user sheet, like userChrome.css: -moz-context-properties is only parsed
  // in privileged sheets, and user !important beats Thunderbird's own rules.
  onStartup() {
    const buttonId = `${EXTENSION_PREFIX}${this.extension.id}`;
    const css = `
      .unified-toolbar [item-id="${buttonId}"] .button-icon.button-icon {
        content: var(--icon-settings) !important;
        -moz-context-properties: fill, stroke !important;
        fill: color-mix(in srgb, currentColor 20%, transparent) !important;
        stroke: currentColor !important;
      }
    `;
    this.sheet = Services.io.newURI(
      `data:text/css,${encodeURIComponent(css)}`
    );
    styleSheetService.loadAndRegisterSheet(
      this.sheet,
      styleSheetService.USER_SHEET
    );
  }

  onShutdown() {
    if (
      this.sheet &&
      styleSheetService.sheetRegistered(this.sheet, styleSheetService.USER_SHEET)
    ) {
      styleSheetService.unregisterSheet(
        this.sheet,
        styleSheetService.USER_SHEET
      );
    }
  }

  getAPI(context) {
    const buttonId = `${EXTENSION_PREFIX}${context.extension.id}`;
    return {
      settingsTab: {
        async open() {
          // What Thunderbird's own Settings menu items call; it reuses an
          // already open Settings tab.
          Services.wm.getMostRecentWindow("mail:3pane")?.openPreferencesTab();
        },

        async placeBeforeSearchBar() {
          // The toolbar layout lives in xulstore, one ordered item list per
          // customized space; spaces without an entry use the defaults.
          const state = getState();
          for (const space of SPACES) {
            const items = (state[space] ?? getDefaultItemIdsForSpace(space))
              .filter(id => id != buttonId);
            const searchBar = items.indexOf("search-bar");
            if (searchBar == -1) {
              continue;
            }
            items.splice(searchBar, 0, buttonId);
            state[space] = items;
          }
          storeState(state);
        },
      },
    };
  }
};
