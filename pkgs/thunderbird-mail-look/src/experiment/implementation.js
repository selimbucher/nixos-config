"use strict";

var { ExtensionCommon } = ChromeUtils.importESModule(
  "resource://gre/modules/ExtensionCommon.sys.mjs"
);
var { MailServices } = ChromeUtils.importESModule(
  "resource:///modules/MailServices.sys.mjs"
);
var { NetUtil } = ChromeUtils.importESModule(
  "resource://gre/modules/NetUtil.sys.mjs"
);
var { getState, storeState } = ChromeUtils.importESModule(
  "resource:///modules/CustomizationState.mjs"
);
var lazy = {};
ChromeUtils.defineESModuleGetters(lazy, {
  Gloda: "resource:///modules/gloda/GlodaPublic.sys.mjs",
  GlodaConstants: "resource:///modules/gloda/GlodaConstants.sys.mjs",
  GlodaMsgSearcher: "resource:///modules/gloda/GlodaMsgSearcher.sys.mjs",
  GlodaSyntheticView: "resource:///modules/gloda/GlodaSyntheticView.sys.mjs",
});

// Where the search field and the message actions go; set as data-ml-layout on
// every mail document, so switching it in the Config Editor applies live.
//   mail    actions and search in the toolbar, like Apple Mail
//   list    actions in the toolbar, search above the message list
//   single  no toolbar row: search above the list, actions above the message
//   minimal single with only the window buttons and the menu above the folder
//           pane, compose beside the search
//   reader  search in the toolbar, actions beside the sender
var LAYOUT_PREF = "extensions.mail-look.layout";
// Look of the folder pane, as data-ml-folders on about:3pane:
//   thunderbird  unchanged
//   mail         Apple Mail's sidebar: account headings, blue icons, plain counts
//   colorful     the same, with Thunderbird's coloured folder icons
var FOLDERS_PREF = "extensions.mail-look.folders";
// The folder pane's header row (Get Messages, New Message, the folder view
// menu), as data-ml-folder-header on about:3pane. single and minimal never
// show it: their top row is the toolbar.
//   hidden  gone
//   quiet   Get Messages and the menu as quiet icons, level with the list
//           header; compose stays in the toolbar
var FOLDER_HEADER_PREF = "extensions.mail-look.folderHeader";
// Rows of the message list, as data-ml-list on about:3pane: cards (two lines)
// or compact (one line). The list's own Table View / Cards View menu switches
// it, so Table View gives the compact rows instead of Thunderbird's table.
var LIST_PREF = "extensions.mail-look.list";
// Logo service base URL, e.g. "https://logos.selim.one/" (see
// ~/Documents/Code/mail-logos); the sender's organizational domain is
// appended. Empty shows initials only.
var LOGO_PREF = "extensions.mail-look.logoBaseURL";
// Bookkeeping: the layout whose toolbar is in place, and the address format
// the cached sender names were last refreshed for.
var TOOLBAR_PREF = "extensions.mail-look.toolbarLayout";
var ADDRESS_FORMAT_PREF = "extensions.mail-look.addressDisplayFormat";

// Unified toolbar of the mail space for each layout. Bump TOOLBAR_VERSION when
// these change, so they get put in place.
var TOOLBAR_VERSION = 3;
var TOOLBARS = {
  mail: [
    "write-message",
    "search-bar",
    "archive",
    "delete",
    "junk",
    "reply",
    "reply-all",
    "forward-inline",
  ],
  list: [
    "write-message",
    "spacer",
    "archive",
    "delete",
    "junk",
    "reply",
    "reply-all",
    "forward-inline",
  ],
  single: ["spacer", "write-message"],
  minimal: ["spacer"],
  reader: ["write-message", "spacer", "search-bar", "spacer"],
};
// Items of add-ons that are gone (the old settings button), taken out of
// every space's toolbar.
var RETIRED_ITEMS = ["ext-settings-button@selim.one"];
// Layouts with the search field in the list header instead of the toolbar.
var HEADER_SEARCH = new Set(["list", "single", "minimal"]);

function currentLayout() {
  const layout = Services.prefs.getStringPref(LAYOUT_PREF, "mail");
  return layout in TOOLBARS ? layout : "mail";
}

var mailLook = class extends ExtensionCommon.ExtensionAPI {
  onStartup() {
    conversationSheetURL = this.extension.rootURI.resolve("conversation-view.css");
    refreshSenderNames();
    applyToolbar();
    Services.obs.addObserver(this, "chrome-document-loaded");
    Services.prefs.addObserver(LAYOUT_PREF, this);
    Services.prefs.addObserver(FOLDERS_PREF, this);
    Services.prefs.addObserver(FOLDER_HEADER_PREF, this);
    Services.prefs.addObserver(LIST_PREF, this);
    Services.prefs.addObserver(LOGO_PREF, this);

    for (const win of Services.wm.getEnumerator("mail:3pane")) {
      this.attach(win);
      for (const tab of win.gTabmail?.tabInfo ?? []) {
        this.attach(tab.chromeBrowser?.contentWindow);
        this.attach(tab.chromeBrowser?.contentWindow?.messageBrowser?.contentWindow);
        this.attach(tab.chromeBrowser?.contentWindow?.multiMessageBrowser?.contentWindow);
      }
    }
    for (const win of Services.wm.getEnumerator("mail:messageWindow")) {
      this.attach(win.messageBrowser?.contentWindow);
    }
  }

  onShutdown(isAppShutdown) {
    if (isAppShutdown) {
      return;
    }
    Services.obs.removeObserver(this, "chrome-document-loaded");
    Services.prefs.removeObserver(LAYOUT_PREF, this);
    Services.prefs.removeObserver(FOLDERS_PREF, this);
    Services.prefs.removeObserver(FOLDER_HEADER_PREF, this);
    Services.prefs.removeObserver(LIST_PREF, this);
    Services.prefs.removeObserver(LOGO_PREF, this);
    for (const controller of controllers.values()) {
      controller.detach();
    }
    controllers.clear();
  }

  observe(subject, topic, data) {
    if (topic == "chrome-document-loaded") {
      this.attach(subject.defaultView);
      return;
    }
    if (data == LAYOUT_PREF) {
      applyToolbar();
    }
    for (const controller of controllers.values()) {
      controller.update(data);
    }
  }

  attach(win) {
    const attachers = {
      "chrome://messenger/content/messenger.xhtml": MainWindow,
      "about:3pane": ThreePane,
      "about:message": MessageView,
      "chrome://messenger/content/multimessageview.xhtml": SummaryView,
    };
    const Controller = attachers[win?.document.documentURI];
    if (!Controller || controllers.has(win)) {
      return;
    }
    const start = () => {
      if (controllers.has(win) || win.closed) {
        return;
      }
      controllers.set(win, new Controller(win));
      win.addEventListener("unload", () => controllers.delete(win), {
        once: true,
      });
    };
    if (win.document.readyState == "complete") {
      start();
    } else {
      win.addEventListener("load", start, { once: true });
    }
  }

  getAPI() {
    return { mailLook: {} };
  }
};

// window -> MainWindow, ThreePane, MessageView or SummaryView
var controllers = new Map();

// The conversation view's stylesheet, shipped in the add-on.
var conversationSheetURL;
var conversationSheetText;

// Thunderbird caches every message's formatted sender and reformats only when
// mail.displayname.version changes. Its settings page bumps that, user.js
// doesn't, so messages from before a change kept "Name <address>".
function refreshSenderNames() {
  const format = Services.prefs.getIntPref("mail.addressDisplayFormat", 0);
  if (Services.prefs.getIntPref(ADDRESS_FORMAT_PREF, -1) == format) {
    return;
  }
  Services.prefs.setIntPref(
    "mail.displayname.version",
    Services.prefs.getIntPref("mail.displayname.version", 0) + 1
  );
  Services.prefs.setIntPref(ADDRESS_FORMAT_PREF, format);
}

// Puts the layout's items in the mail space's toolbar, once per layout
// change, so buttons arranged later in Customize stay put.
function applyToolbar() {
  const applied = `${currentLayout()}@${TOOLBAR_VERSION}`;
  if (Services.prefs.getStringPref(TOOLBAR_PREF, "") == applied) {
    return;
  }
  const state = getState();
  for (const space of Object.keys(state)) {
    state[space] = state[space].filter(id => !RETIRED_ITEMS.includes(id));
  }
  state.mail = TOOLBARS[currentLayout()];
  storeState(state);
  Services.prefs.setStringPref(TOOLBAR_PREF, applied);
}

// ---------------------------------------------------------------------------
// Main window: layout attributes, the toolbar's search field.

class MainWindow {
  constructor(win) {
    this.win = win;
    this.root = win.document.documentElement;
    this.tabmail = win.document.getElementById("tabmail");
    this.tabMonitor = {
      monitorName: "mailLook",
      onTabTitleChanged() {},
      onTabOpened() {},
      onTabClosing() {},
      onTabPersist() {},
      onTabRestored() {},
      onTabSwitched: () => {
        this.update();
        // The toolbar field is shared by all tabs; show this tab's search.
        this.toolbarField?.overrideSearchTerm(this.currentSearch()?.text ?? "");
      },
    };
    this.tabmail.registerTabMonitor(this.tabMonitor);

    // The spaces toolbar starts closed; mail-look.css hides the button that
    // would bring it back, View > Toolbars still does. Stored right away too
    // (Thunderbird only stores it on a clean exit), so the next start doesn't
    // show it until this add-on has loaded.
    const { gSpacesToolbar } = win;
    this.closeSpaces = () => {
      if (!gSpacesToolbar.isHidden) {
        gSpacesToolbar.toggleToolbar(true);
      }
      Services.xulStore.setValue(gSpacesToolbar.docURL, "spacesToolbar", "hidden", "true");
    };
    if (gSpacesToolbar.isLoaded) {
      this.closeSpaces();
    } else {
      win.addEventListener("spaces-toolbar-ready", this.closeSpaces, { once: true });
    }

    // In a mail tab the toolbar field is the one search: typing filters the
    // open folder, Enter searches all mail. Thunderbird's own suggestions
    // popup and results tab stay for the other tabs.
    this.onSearchEvent = event => {
      const search = this.currentSearch();
      if (event.target.localName != "global-search-bar" || !search) {
        return;
      }
      event.stopImmediatePropagation();
      event.preventDefault();
      if (event.type == "autocomplete") {
        search.setText(event.detail);
      } else {
        search.setScope("all");
      }
    };
    win.addEventListener("autocomplete", this.onSearchEvent, true);
    win.addEventListener("search", this.onSearchEvent, true);

    // Ctrl+K goes to the one search field, wherever the layout put it.
    const { QuickSearchFocus } = win;
    this.quickSearchFocus = QuickSearchFocus;
    const mainWindow = this;
    win.QuickSearchFocus = function (...args) {
      if (!mainWindow.currentSearch()?.focus()) {
        QuickSearchFocus.apply(this, args);
      }
    };

    this.update();
  }

  get toolbarField() {
    return this.win.document.querySelector(
      "#unifiedToolbarContent global-search-bar"
    );
  }

  currentSearch() {
    const tab = this.tabmail.currentTabInfo;
    if (tab?.mode.name != "mail3PaneTab") {
      return null;
    }
    return controllers.get(tab.chromeBrowser?.contentWindow)?.search ?? null;
  }

  update() {
    const tab = this.tabmail.currentTabInfo;
    this.root.dataset.mlLayout = currentLayout();
    this.root.dataset.mlTab = tab?.mode.name ?? "";

    // Where the panes of the open mail tab start, in window pixels: single
    // puts the toolbar over the folder pane, mail lines the toolbar's groups
    // up with the panes below.
    const about3Pane =
      tab?.mode.name == "mail3PaneTab" ? tab.chromeBrowser?.contentWindow : null;
    const doc = about3Pane?.document;
    const paneRect = id => {
      const element = doc?.getElementById(id);
      return element?.checkVisibility() ? element.getBoundingClientRect() : null;
    };
    const folderPane = paneRect("folderPane");
    const threadPane = paneRect("threadPane");
    const messagePane = paneRect("messagePane");
    const offset = tab?.chromeBrowser?.getBoundingClientRect().x ?? 0;
    const content = this.win.document.getElementById("unifiedToolbarContent");
    const style = this.root.style;
    style.setProperty("--ml-sidebar-width", `${Math.round(folderPane ? threadPane?.x ?? folderPane.right : 0)}px`);
    this.root.toggleAttribute("data-ml-sidebar", !!folderPane);
    // Only for the side-by-side panes; stacked or hidden ones keep a plain row.
    const zones = !!(threadPane && messagePane && messagePane.x > threadPane.x && content);
    this.root.toggleAttribute("data-ml-zones", zones);
    if (zones) {
      const contentStart =
        content.getBoundingClientRect().x +
        parseFloat(this.win.getComputedStyle(content).paddingInlineStart);
      style.setProperty("--ml-toolbar-x", `${Math.round(contentStart)}px`);
      style.setProperty("--ml-list-x", `${Math.round(offset + threadPane.x)}px`);
      style.setProperty("--ml-reader-x", `${Math.round(offset + messagePane.x)}px`);
    }
  }

  detach() {
    this.tabmail.unregisterTabMonitor(this.tabMonitor);
    this.win.removeEventListener("spaces-toolbar-ready", this.closeSpaces);
    this.win.removeEventListener("autocomplete", this.onSearchEvent, true);
    this.win.removeEventListener("search", this.onSearchEvent, true);
    this.win.QuickSearchFocus = this.quickSearchFocus;
    delete this.root.dataset.mlLayout;
    delete this.root.dataset.mlTab;
    this.root.removeAttribute("data-ml-sidebar");
    this.root.removeAttribute("data-ml-zones");
    for (const name of ["--ml-sidebar-width", "--ml-toolbar-x", "--ml-list-x", "--ml-reader-x"]) {
      this.root.style.removeProperty(name);
    }
  }
}

// ---------------------------------------------------------------------------
// Mail tab: message list badges and dates, the search.

class ThreePane {
  constructor(about3Pane) {
    this.win = about3Pane;
    this.ready = this.start();
  }

  async start() {
    const about3Pane = this.win;
    await about3Pane.customElements.whenDefined("thread-card");
    if (controllers.get(about3Pane) != this) {
      return;
    }

    // The tree reuses row elements while scrolling, so everything a row shows
    // is (re)derived from its current message on every fillRow. That's what
    // keeps a badge from sticking to the wrong message.
    const ThreadCard = about3Pane.customElements.get("thread-card");
    const { threadPane } = about3Pane;
    const { fillRow } = ThreadCard.prototype;
    const { densityChange } = threadPane;
    ThreadCard.prototype.fillRow = function () {
      fillRow.call(this);
      decorateCard(this);
    };
    // Thunderbird sizes cards for its own layout; the tree needs the real
    // height of ours to lay out and scroll.
    threadPane.densityChange = async function () {
      await densityChange.call(this);
      const rowHeight = parseFloat(
        about3Pane
          .getComputedStyle(about3Pane.threadTree)
          .getPropertyValue("--ml-row-height")
      );
      if (rowHeight > 0) {
        ThreadCard.ROW_HEIGHT = rowHeight;
      }
    };
    this.unpatch = () => {
      ThreadCard.prototype.fillRow = fillRow;
      threadPane.densityChange = densityChange;
    };

    this.search = new Search(about3Pane);
    this.conversation = new Conversation(about3Pane);
    this.listView = new ListView(about3Pane);
    this.headings = new AccountHeadings(about3Pane);
    // minimal's compose, at the end of the list header.
    this.composeButton = about3Pane.document.createElement("button");
    this.composeButton.id = "mlCompose";
    this.composeButton.className = "button button-flat icon-button icon-only";
    this.composeButton.title = "New Message";
    this.composeButton.addEventListener("click", event => about3Pane.top.MsgNewMessage(event));
    this.resizeObserver = new about3Pane.ResizeObserver(() =>
      controllers.get(about3Pane.top)?.update()
    );
    for (const id of ["folderPane", "threadPane", "messagePane"]) {
      this.resizeObserver.observe(about3Pane.document.getElementById(id));
    }
    this.update();
  }

  update(changedPref) {
    if (!this.search) {
      return;
    }
    if (changedPref == LOGO_PREF) {
      this.win.threadTree?.invalidate();
      return;
    }
    const layout = currentLayout();
    const root = this.win.document.documentElement;
    root.dataset.mlLayout = layout;
    root.dataset.mlFolders = Services.prefs.getStringPref(FOLDERS_PREF, "thunderbird");
    const folderHeader = Services.prefs.getStringPref(FOLDER_HEADER_PREF, "hidden");
    root.dataset.mlFolderHeader = folderHeader;
    // Thunderbird's own switch for the header as well, which it reads before
    // the first paint, so a hidden header doesn't flash until this add-on and
    // its attributes are there.
    const headerHidden = layout == "single" || layout == "minimal" || folderHeader != "quiet";
    if (this.win.document.getElementById("folderPaneHeaderBar").hidden != headerHidden) {
      this.win.folderPane.toggleHeader(headerHidden);
    }
    root.dataset.mlList = Services.prefs.getStringPref(LIST_PREF, "cards");
    this.search.placeField(layout);
    if (layout == "minimal") {
      root.querySelector("#threadPaneHeaderBar .list-header-bar-container-end").append(this.composeButton);
    } else {
      this.composeButton.remove();
    }
    // Recomputes the row height from the CSS and refills rows.
    this.win.threadPane.updateThreadItemSize();
  }

  detach() {
    this.unpatch?.();
    this.search?.detach();
    this.conversation?.detach();
    this.listView?.detach();
    this.headings?.detach();
    this.composeButton?.remove();
    this.resizeObserver?.disconnect();
    for (const badge of this.win.document.querySelectorAll(".ml-badge")) {
      badge.remove();
    }
    delete this.win.document.documentElement.dataset.mlLayout;
    delete this.win.document.documentElement.dataset.mlFolders;
    delete this.win.document.documentElement.dataset.mlFolderHeader;
    delete this.win.document.documentElement.dataset.mlList;
    this.win.threadPane.updateThreadItemSize();
  }
}

// The list's Table View / Cards View menu picks between compact and card rows;
// Thunderbird's table isn't used.
class ListView {
  constructor(about3Pane) {
    this.win = about3Pane;
    const { commandController, threadPaneHeader } = about3Pane;
    this.callbacks = {};
    for (const [command, list] of [
      ["cmd_threadPaneViewTable", "compact"],
      ["cmd_threadPaneViewCards", "cards"],
    ]) {
      this.callbacks[command] = commandController._callbackCommands[command];
      commandController.registerCallback(command, () => {
        Services.prefs.setStringPref(LIST_PREF, list);
      });
    }
    // A table view chosen before the add-on (or elsewhere) becomes compact rows.
    if (Services.prefs.getIntPref("mail.threadpane.listview", 0) == 1) {
      Services.prefs.setStringPref(LIST_PREF, "compact");
      Services.prefs.setIntPref("mail.threadpane.listview", 0);
    }

    const doc = about3Pane.document;
    this.tableItem = doc.getElementById("threadPaneTableView");
    this.tableLabel = this.tableItem.getAttribute("data-l10n-id");
    doc.l10n.pauseObserving();
    this.tableItem.removeAttribute("data-l10n-id");
    this.tableItem.setAttribute("label", "List View");
    doc.l10n.resumeObserving();
    this.updateMenu = threadPaneHeader.updateDisplayContextMenu;
    const listView = this;
    threadPaneHeader.updateDisplayContextMenu = function (...args) {
      listView.updateMenu.apply(this, args);
      const compact = Services.prefs.getStringPref(LIST_PREF, "cards") == "compact";
      doc.getElementById("threadPaneTableView").toggleAttribute("checked", compact);
      doc.getElementById("threadPaneCardsView").toggleAttribute("checked", !compact);
    };
  }

  detach() {
    const { commandController, threadPaneHeader } = this.win;
    for (const [command, callback] of Object.entries(this.callbacks)) {
      commandController.registerCallback(command, callback);
    }
    delete threadPaneHeader.updateDisplayContextMenu;
    this.tableItem.setAttribute("data-l10n-id", this.tableLabel);
  }
}

// With the sidebar looks, accounts are headings: clicking one does nothing
// (Thunderbird would swap the list and message for the account's start page),
// and arrow keys step over them.
class AccountHeadings {
  constructor(about3Pane) {
    this.win = about3Pane;
    const folderPane = about3Pane.document.getElementById("folderPane");
    this.folderPane = folderPane;
    const active = () =>
      ["mail", "colorful"].includes(about3Pane.document.documentElement.dataset.mlFolders);
    const isHeading = row => !!row?.dataset.serverType;

    this.onClick = event => {
      const row = event.target.closest?.("#folderTree li");
      if (active() && isHeading(row) && !event.target.closest(".twisty")) {
        event.stopPropagation();
        event.preventDefault();
      }
    };
    folderPane.addEventListener("click", this.onClick, true);

    this.lastIndex = about3Pane.folderTree.selectedIndex;
    this.onSelect = event => {
      const tree = about3Pane.folderTree;
      const index = tree.selectedIndex;
      if (active() && isHeading(tree.selectedRow)) {
        event.stopImmediatePropagation();
        const rows = tree.rows;
        const next = rows[index < this.lastIndex ? index - 1 : index + 1];
        tree.updateSelection(next && !isHeading(next) ? next : rows[this.lastIndex]);
        return;
      }
      this.lastIndex = index;
    };
    folderPane.addEventListener("select", this.onSelect, true);
  }

  detach() {
    this.folderPane.removeEventListener("click", this.onClick, true);
    this.folderPane.removeEventListener("select", this.onSelect, true);
  }
}

// A selected thread shows as a conversation (Thunderbird's own view, behind
// mail.thread.conversation.enabled): the add-on styles it, gives the earlier
// messages badges and plain names, and falls back to the thread summary when
// Thunderbird's index doesn't know the thread yet.
class Conversation {
  constructor(about3Pane) {
    this.win = about3Pane;
    const { messagePane } = about3Pane;
    this.messagePane = messagePane;

    const conversation = this;
    this.displayMessages = messagePane.displayMessages;
    // Bumped by every display, so a late fallback can't replace a newer one.
    this.generation = 0;
    messagePane.displayMessages = function (messages = []) {
      const generation = ++conversation.generation;
      const result = conversation.displayMessages.call(this, messages);
      const view = this.conversationView;
      if (view && !view.hidden) {
        conversation.attachView(view);
        conversation.fallBackIfEmpty(view, messages, generation);
      }
      return result;
    };
  }

  async attachView(view) {
    if (this.view == view) {
      return;
    }
    this.view = view;
    conversationSheetText ??= readText(conversationSheetURL);
    const sheet = new this.win.CSSStyleSheet();
    sheet.replaceSync(await conversationSheetText);
    view.shadowRoot.adoptedStyleSheets = [
      ...view.shadowRoot.adoptedStyleSheets,
      sheet,
    ];

    const main = view.shadowRoot.getElementById("mainConversation");
    this.observer = new this.win.MutationObserver(mutations => {
      if (mutations.some(({ target }) => !target.parentElement?.closest(".ml-badge"))) {
        this.decorate(main);
      }
    });
    this.observer.observe(main, { childList: true, subtree: true, characterData: true });
  }

  // Earlier messages: plain name, badge, unread dot.
  decorate(main) {
    const messages = this.view?.messages ?? [];
    for (const article of main.querySelectorAll("article[aria-expanded='false']")) {
      const message = messages.find(m => m.messageId == article.dataset.messageId);
      const address = article.querySelector("address");
      if (!message || !address) {
        continue;
      }
      const [person = {}] = MailServices.headerParser.parseDecodedHeader(
        message.mime2DecodedAuthor
      );
      // Thunderbird writes "Name <address>", or "Me" for your own messages.
      if (address.textContent.includes("<") && person.name) {
        address.textContent = person.name;
      }
      article.classList.toggle("ml-unread", !message.isRead);
      let badge = article.querySelector(":scope > .ml-badge");
      if (!badge) {
        badge = createBadge(article.ownerDocument);
        article.prepend(badge);
      }
      fillBadge(badge, person);
    }
  }

  // The view needs the thread in Thunderbird's global index; without it, it
  // stays empty. Show the summary instead.
  async fallBackIfEmpty(view, messages, generation) {
    const main = view.shadowRoot.getElementById("mainConversation");
    for (let waited = 0; waited < 3000 && !main.childElementCount; waited += 250) {
      await new Promise(resolve => this.win.setTimeout(resolve, 250));
    }
    if (main.childElementCount || generation != this.generation || view.hidden) {
      return;
    }
    const { messagePane, gDBView } = this.win;
    view.hidden = true;
    view.clear();
    messagePane.multiMessageBrowser.contentWindow.gMessageSummary.summarize(
      "thread",
      messages,
      gDBView,
      selected =>
        messagePane.dispatchEvent(
          new this.win.CustomEvent("show-single-message", {
            bubbles: true,
            detail: {
              messages: selected
                .map(m => gDBView.findIndexOfMsgHdr(m, true))
                .filter(i => i != this.win.nsMsgViewIndex_None),
            },
          })
        )
    );
    messagePane.multiMessageBrowser.hidden = false;
  }

  detach() {
    // The patch is an own property; removing it restores the element's method.
    delete this.messagePane.displayMessages;
    this.observer?.disconnect();
  }
}

// One search per mail tab, fed by whichever field the layout shows. Typing
// filters the open folder through the quick filter; the scope bar under the
// list header (or Enter) switches to Thunderbird's full-text index across all
// mail, whose results replace the list in place. Clearing the field or picking
// a folder ends it.
class Search {
  constructor(about3Pane) {
    this.win = about3Pane;
    this.doc = about3Pane.document;
    this.text = "";
    this.scope = "folder";
    // Folder the all-mail results came from, to go back to.
    this.folderURI = null;
    // Bumped by every search, so a slow index query can't show stale results.
    this.generation = 0;
    // Set while this class changes the view itself.
    this.busy = false;

    const doc = this.doc;
    this.field = doc.createElement("search-bar");
    this.field.id = "mlSearch";
    this.field.setAttribute("label", "Search");
    this.field.setAttribute("placeholder", "Search");
    this.field.setAttribute("maxlength", "192");
    this.field.addEventListener("autocomplete", event =>
      this.setText(event.detail)
    );
    this.field.addEventListener("search", event => {
      event.preventDefault();
      this.setScope("all");
    });
    this.field.addEventListener("keydown", event => {
      if (event.key == "ArrowDown") {
        event.preventDefault();
        this.win.threadTree.table.body.focus();
        if (this.win.threadTree.selectedIndex == -1) {
          this.win.threadTree.selectedIndex = 0;
        }
      }
    });

    this.scopeBar = doc.createElement("div");
    this.scopeBar.id = "mlScope";
    this.scopeBar.hidden = true;
    this.scopeBar.setAttribute("role", "radiogroup");
    this.folderButton = doc.createElement("button");
    this.allButton = doc.createElement("button");
    this.allButton.textContent = "All Mail";
    for (const [button, scope] of [
      [this.folderButton, "folder"],
      [this.allButton, "all"],
    ]) {
      button.className = "ml-scope-button";
      button.setAttribute("role", "radio");
      button.addEventListener("click", () => this.setScope(scope));
      this.scopeBar.append(button);
    }
    this.countLabel = doc.createElement("span");
    this.countLabel.className = "ml-scope-count";
    this.scopeBar.append(this.countLabel);
    // Keeps the result count current as the filter or index query settles.
    const { dbViewWrapperListener } = about3Pane;
    this.onMessageCountsChanged = dbViewWrapperListener.onMessageCountsChanged;
    const search = this;
    dbViewWrapperListener.onMessageCountsChanged = function (...args) {
      search.onMessageCountsChanged.apply(this, args);
      search.renderCount();
    };
    doc.getElementById("threadPaneHeaderBar").after(this.scopeBar);

    // Picking a folder while all-mail results show: drop the results view
    // first, Thunderbird doesn't switch folders out of a synthetic view.
    this.onFolderSelect = () => {
      if (!this.busy && this.win.gViewWrapper?.isSynthetic && this.scope == "all") {
        this.closeResults();
        this.reset();
      }
    };
    doc
      .getElementById("folderPane")
      .addEventListener("select", this.onFolderSelect, true);
    // Any other folder change ends a folder search; the quick filter forgets
    // its text too.
    this.onFolderChanged = () => {
      if (!this.busy && this.text) {
        this.reset();
      }
    };
    about3Pane.addEventListener("folderURIChanged", this.onFolderChanged);
    // Closing the filter chips row clears every quick filter, ours included.
    this.onChipsToggled = () => {
      if (this.text && this.scope == "folder") {
        this.filterFolder(this.text);
      }
    };
    about3Pane.addEventListener("qfbtoggle", this.onChipsToggled);
    // Ctrl+Shift+K, the quick filter's shortcut, also goes to the one field.
    const { commandController } = about3Pane;
    this.showQuickFilter =
      commandController._callbackCommands.cmd_showQuickFilterBar;
    commandController.registerCallback("cmd_showQuickFilterBar", () => {
      if (!this.focus()) {
        this.showQuickFilter?.();
      }
    });
  }

  placeField(layout) {
    if (HEADER_SEARCH.has(layout)) {
      this.doc
        .querySelector("#threadPaneHeaderBar .list-header-bar-container-start")
        .after(this.field);
    } else {
      this.field.remove();
    }
  }

  focus() {
    const field = this.field.isConnected
      ? this.field
      : this.win.top.document.querySelector(
          "#unifiedToolbarContent global-search-bar"
        );
    if (!field?.checkVisibility()) {
      return false;
    }
    field.focus();
    return true;
  }

  setText(text) {
    if (text == this.text) {
      return;
    }
    this.text = text;
    if (!text) {
      this.end();
    } else if (this.scope == "all") {
      this.searchAll();
    } else {
      this.filterFolder(text);
    }
    this.render();
  }

  setScope(scope) {
    if (!this.text || scope == this.scope) {
      return;
    }
    this.scope = scope;
    if (scope == "all") {
      this.searchAll();
    } else {
      this.generation++;
      this.closeResults();
      this.showFolder();
      this.filterFolder(this.text);
    }
    this.render();
  }

  // Quick filter text on the open folder; null clears it. With apply false it's
  // only stored, for the next view to pick up.
  filterFolder(text, { apply = true } = {}) {
    const { quickFilterBar } = this.win;
    let states;
    try {
      states = JSON.parse(
        Services.xulStore.getValue(
          "chrome://messenger/content/messenger.xhtml",
          "quickFilter",
          "textFilters"
        )
      );
    } catch {}
    // Cleared means no text, not no entry: the quick filter carries the entry
    // over to the next folder's view and fails without it.
    quickFilterBar.filterer.setFilterValue("text", {
      text,
      states: states ?? { sender: true, recipients: true, subject: true, body: false },
    });
    if (apply) {
      quickFilterBar.updateSearch();
    }
  }

  async searchAll() {
    const { text } = this;
    const generation = ++this.generation;
    // The index matches whole words only; every plain word of three or more
    // letters becomes a prefix, so all mail finds what the folder search
    // finds while typing ("gala" finds Galaxus). Quoted phrases and CJK
    // terms stay as Thunderbird searches them.
    const searcher = new lazy.GlodaMsgSearcher(null, text);
    searcher.fulltextTerms = searcher.fulltextTerms.map(term =>
      /^[\p{L}\p{N}]{3,}$/u.test(term) && !/[\u2000-\uffff]/u.test(term) ? `${term}*` : term
    );
    const collection = searcher.getCollection();
    const items = await new Promise(resolve => {
      collection.listener = {
        onItemsAdded() {},
        onItemsModified() {},
        onItemsRemoved() {},
        onQueryCompleted: completed => resolve(completed.items),
      };
    });
    if (generation != this.generation) {
      return;
    }
    const win = this.win;
    if (!win.gViewWrapper?.isSynthetic) {
      this.folderURI = win.gFolder?.URI ?? this.folderURI;
    }
    this.busy = true;
    try {
      // The results view mustn't inherit the folder's filter. Cleared only
      // now, as the results replace the list: clearing it when the search
      // starts showed the whole folder until the index answered.
      this.filterFolder(null, { apply: false });
      win.restoreState({
        syntheticView: new lazy.GlodaSyntheticView({
          collection: lazy.Gloda.explicitCollection(
            lazy.GlodaConstants.NOUN_MESSAGE,
            items
          ),
        }),
        folderPaneVisible: !win.paneLayout.folderPaneSplitter.isCollapsed,
        title: "All Mail",
      });
      // The folder stays selected (the folder list can't select nothing), so
      // the title says what the list shows.
      win.threadPaneHeader.folderName.textContent = "All Mail";
    } finally {
      this.busy = false;
    }
    this.render();
  }

  closeResults() {
    const win = this.win;
    if (!win.gViewWrapper?.isSynthetic) {
      return;
    }
    win.gViewWrapper.close();
    win.gViewWrapper = null;
    win.paneLayout.folderPaneSplitter.isDisabled = false;
  }

  showFolder() {
    const win = this.win;
    if (!this.folderURI || win.gViewWrapper) {
      return;
    }
    this.busy = true;
    try {
      if (win.folderTree.selectedRow?.uri == this.folderURI) {
        // Still selected: have the folder list open it again.
        win.folderPane._onSelect();
      } else {
        win.displayFolder(this.folderURI);
      }
    } finally {
      this.busy = false;
    }
  }

  // The field was cleared.
  end() {
    this.generation++;
    if (this.scope == "all") {
      this.closeResults();
      this.showFolder();
    }
    this.filterFolder(null);
    this.scope = "folder";
  }

  // Something else ended the search; empty the fields to match.
  reset() {
    this.generation++;
    this.text = "";
    this.scope = "folder";
    this.render();
    // A field that isn't shown has no input to empty.
    if (this.field.isConnected) {
      this.field.overrideSearchTerm("");
    }
    const controller = controllers.get(this.win.top);
    if (controller?.currentSearch() == this) {
      controller.toolbarField?.overrideSearchTerm("");
    }
  }

  render() {
    this.scopeBar.hidden = !this.text;
    this.doc.documentElement.toggleAttribute("data-ml-searching", !!this.text);
    this.renderCount();
    const folder = MailServices.folderLookup.getFolderForURL(
      this.scope == "all" ? this.folderURI : this.win.gFolder?.URI ?? ""
    );
    this.folderButton.textContent = folder?.localizedName ?? "Folder";
    this.folderButton.ariaChecked = String(this.scope == "folder");
    this.allButton.ariaChecked = String(this.scope == "all");
  }

  renderCount() {
    const count = this.text ? this.win.gDBView?.numMsgsInView : undefined;
    this.countLabel.textContent =
      count === undefined ? "" : `${count} ${count == 1 ? "result" : "results"}`;
  }

  detach() {
    if (this.text) {
      this.end();
    }
    this.win.dbViewWrapperListener.onMessageCountsChanged =
      this.onMessageCountsChanged;
    this.doc.documentElement.removeAttribute("data-ml-searching");
    this.field.remove();
    this.scopeBar.remove();
    this.doc
      .getElementById("folderPane")
      .removeEventListener("select", this.onFolderSelect, true);
    this.win.removeEventListener("folderURIChanged", this.onFolderChanged);
    this.win.removeEventListener("qfbtoggle", this.onChipsToggled);
    this.win.commandController.registerCallback(
      "cmd_showQuickFilterBar",
      this.showQuickFilter
    );
  }
}

// ---------------------------------------------------------------------------
// Message: the sender's badge in the header.

class MessageView {
  constructor(aboutMessage) {
    this.win = aboutMessage;
    const doc = aboutMessage.document;
    this.fromBox = doc.getElementById("expandedfromBox");
    this.recipientBoxes = ["expandedtoBox", "expandedccBox"].map(id => doc.getElementById(id));
    // The header rebuilds its recipients for every message (and again when
    // an address book lookup finishes), so the badge follows the DOM.
    this.observer = new aboutMessage.MutationObserver(mutations => {
      if (mutations.some(({ target }) => !target.closest?.(".ml-badge"))) {
        this.decorate();
      }
    });
    this.observer.observe(this.fromBox, { childList: true, subtree: true });
    // To and Cc: names only, like Mail; the address stays in the tooltip.
    this.recipientObserver = new aboutMessage.MutationObserver(() => this.shortenRecipients());
    for (const box of this.recipientBoxes) {
      this.recipientObserver.observe(box, { childList: true, subtree: true, characterData: true });
    }
    this.update();
  }

  shortenRecipients() {
    for (const line of this.win.document.querySelectorAll(
      "#expandedtoBox .recipient-single-line, #expandedccBox .recipient-single-line"
    )) {
      const recipient = line.closest(".header-recipient");
      const name = recipient?.displayName;
      if (name && line.textContent != name && line.textContent.includes("<")) {
        recipient.title ||= line.textContent;
        line.textContent = name;
      }
    }
  }

  update(changedPref) {
    if (changedPref == LOGO_PREF) {
      this.fromBox.querySelector(".ml-badge")?.remove();
    }
    this.win.document.documentElement.dataset.mlLayout = currentLayout();
    this.decorate();
    this.shortenRecipients();
  }

  decorate() {
    const sender = this.fromBox.querySelector(".header-recipient");
    const avatar = sender?.querySelector(".recipient-avatar");
    if (!avatar) {
      return;
    }
    let badge = avatar.querySelector(".ml-badge");
    // A contact photo from the address book wins.
    if (avatar.classList.contains("has-avatar")) {
      badge?.remove();
      return;
    }
    if (!badge) {
      badge = createBadge(this.win.document);
      avatar.append(badge);
    }
    // From the element itself rather than the loaded message, so a badge
    // can't belong to a different message than the name beside it.
    fillBadge(badge, {
      name: sender.displayName,
      email: sender.emailAddress ?? "",
    });
  }

  detach() {
    this.observer.disconnect();
    this.recipientObserver.disconnect();
    this.fromBox.querySelector(".ml-badge")?.remove();
    delete this.win.document.documentElement.dataset.mlLayout;
  }
}

// ---------------------------------------------------------------------------
// Thread summary (a collapsed thread or several messages): names without
// addresses, and a badge beside each message.

class SummaryView {
  constructor(win) {
    this.win = win;
    this.list = win.document.getElementById("messageList");
    // It loads in a content-type browser, which userChrome.css doesn't reach,
    // so its part of mail-look.css comes in as a sheet of this window.
    const userChrome = Services.dirsvc.get("UChrm", Ci.nsIFile);
    userChrome.append("userChrome.css");
    if (userChrome.exists()) {
      this.sheet = Services.io.newFileURI(userChrome).spec;
      win.windowUtils.loadSheetUsingURIString(this.sheet, win.windowUtils.USER_SHEET);
    }
    // Items are rebuilt for every selection, and their author text is filled
    // in again once the message body has been read.
    this.observer = new win.MutationObserver(mutations => {
      if (mutations.some(({ target }) => !target.parentElement?.closest(".ml-badge"))) {
        this.decorate();
      }
    });
    this.observer.observe(this.list, {
      childList: true,
      subtree: true,
      characterData: true,
    });
    this.update();
  }

  update(changedPref) {
    if (changedPref == LOGO_PREF) {
      for (const badge of this.list.querySelectorAll(".ml-badge")) {
        badge.remove();
      }
    }
    this.win.document.documentElement.dataset.mlLayout = currentLayout();
    this.decorate();
  }

  decorate() {
    for (const item of this.list.children) {
      const author = item.querySelector(".author");
      if (!author) {
        continue;
      }
      const [person] = MailServices.headerParser.parseDecodedHeader(
        author.textContent
      );
      // "Name <address>" becomes "Name"; the address is kept for the badge.
      if (person?.email) {
        item.dataset.mlEmail = person.email;
        if (person.name && author.textContent != person.name) {
          author.textContent = person.name;
        }
      }
      let badge = item.querySelector(":scope > .ml-badge");
      if (!badge) {
        badge = createBadge(this.win.document);
        item.prepend(badge);
      }
      fillBadge(badge, {
        name: author.textContent,
        email: item.dataset.mlEmail ?? "",
      });
    }
  }

  detach() {
    this.observer.disconnect();
    if (this.sheet) {
      this.win.windowUtils.removeSheetUsingURIString(
        this.sheet,
        this.win.windowUtils.USER_SHEET
      );
    }
    for (const badge of this.list.querySelectorAll(".ml-badge")) {
      badge.remove();
    }
    delete this.win.document.documentElement.dataset.mlLayout;
  }
}

// ---------------------------------------------------------------------------
// Badges: logo or initials.

function decorateCard(card) {
  const properties = card.dataset.properties?.split(" ") ?? [];
  // Group headers of a grouped-by-sort view.
  if (properties.includes("dummy")) {
    return;
  }
  let hdr;
  try {
    hdr = card.view.getMsgHdrAt(card._index);
  } catch {
    return;
  }

  card.dateLine.textContent = formatDate(new Date(hdr.date / 1000));

  let badge = card.querySelector(".ml-badge");
  if (!badge) {
    badge = createBadge(card.ownerDocument);
    card.querySelector(".read-status-column").after(badge);
  }
  // Same person the card's sender line names: recipients in Sent and the like.
  const showsRecipient =
    card.ownerDocument.defaultView.threadPane.cardColumns[1] == "recipientCol";
  const [person = {}] = MailServices.headerParser.parseDecodedHeader(
    showsRecipient ? hdr.mime2DecodedRecipients : hdr.mime2DecodedAuthor
  );
  fillBadge(badge, person);
}

function createBadge(document) {
  const badge = document.createElement("div");
  badge.className = "ml-badge";
  badge.setAttribute("aria-hidden", "true");
  const initialsElement = document.createElement("span");
  initialsElement.className = "ml-initials";
  const img = document.createElement("img");
  img.className = "ml-logo";
  img.alt = "";
  img.addEventListener("error", () => badge.classList.remove("ml-has-logo"));
  badge.append(initialsElement, img);
  return badge;
}

function fillBadge(badge, { name, email = "" }) {
  const initialsElement = badge.querySelector(".ml-initials");
  const text = initials(name, email);
  // Unchanged text stays untouched: rewriting it would be a DOM mutation,
  // and the message header watches its sender for those.
  if (initialsElement.textContent != text) {
    initialsElement.textContent = text;
  }
  // Each sender keeps its own tint wherever the badge appears.
  const tint = hue(email || name || "");
  if (badge.style.getPropertyValue("--ml-hue") != tint) {
    badge.style.setProperty("--ml-hue", tint);
  }

  const base = Services.prefs.getStringPref(LOGO_PREF, "");
  const domain = orgDomain(email);
  const logoURL = base && domain ? base + encodeURIComponent(domain) : "";
  if (badge.dataset.logoUrl == logoURL) {
    return;
  }
  badge.dataset.logoUrl = logoURL;
  if (logos.has(logoURL)) {
    // Already fetched: no flash of initials while scrolling.
    showLogo(badge, logos.get(logoURL));
    return;
  }
  showLogo(badge, null);
  if (logoURL) {
    fetchLogo(logoURL).then(dataURL => {
      // Only if the badge still stands for that domain.
      if (badge.dataset.logoUrl == logoURL) {
        showLogo(badge, dataURL);
      }
    });
  }
}

function showLogo(badge, dataURL) {
  const img = badge.querySelector(".ml-logo");
  if (dataURL) {
    img.src = dataURL;
  } else {
    img.removeAttribute("src");
  }
  badge.classList.toggle("ml-has-logo", !!dataURL);
}

function readText(url) {
  return new Promise((resolve, reject) => {
    NetUtil.asyncFetch({ uri: url, loadUsingSystemPrincipal: true }, (stream, status) => {
      if (!Components.isSuccessCode(status)) {
        reject(new Components.Exception(`Couldn't read ${url}`, status));
        return;
      }
      resolve(
        NetUtil.readInputStreamToString(stream, stream.available(), { charset: "UTF-8" })
      );
    });
  });
}

// logo URL -> data: URL, or null when the service has no logo
var logos = new Map();
// logo URL -> pending fetch
var logoFetches = new Map();

// The mail documents' CSP only allows data: images, so logos are fetched here,
// with the system principal, and handed over as data: URLs. The HTTP cache
// keeps them across restarts (the service sends Cache-Control).
function fetchLogo(url) {
  if (!logoFetches.has(url)) {
    const fetched = new Promise(resolve => {
      const channel = NetUtil.newChannel({ uri: url, loadUsingSystemPrincipal: true });
      NetUtil.asyncFetch(channel, (stream, status) => {
        try {
          if (
            !Components.isSuccessCode(status) ||
            !(channel instanceof Ci.nsIHttpChannel) ||
            !channel.requestSucceeded ||
            !channel.contentType.startsWith("image/")
          ) {
            resolve(null);
            return;
          }
          const bytes = new Uint8Array(NetUtil.readInputStream(stream, stream.available()));
          const base64 = ChromeUtils.base64URLEncode(bytes, { pad: true })
            .replaceAll("-", "+")
            .replaceAll("_", "/");
          resolve(`data:${channel.contentType};base64,${base64}`);
        } catch {
          resolve(null);
        }
      });
    }).then(dataURL => {
      logos.set(url, dataURL);
      logoFetches.delete(url);
      return dataURL;
    });
    logoFetches.set(url, fetched);
  }
  return logoFetches.get(url);
}

var timeFormat = new Services.intl.DateTimeFormat(undefined, {
  timeStyle: "short",
});
var dateFormat = new Services.intl.DateTimeFormat(undefined, {
  dateStyle: "short",
});

function formatDate(date) {
  const isToday = date.toDateString() == new Date().toDateString();
  return (isToday ? timeFormat : dateFormat).format(date);
}

// "Theo Weidmann (via Moodle Course)" -> "TW", "careers-noreply@…" -> "CN"
function initials(name, email) {
  const source = name?.replace(/\(.*?\)|\[.*?\]|["']/g, "").trim() ||
    email.split("@")[0];
  const words = source.split(/[\s._+-]+/).filter(word => /[\p{L}\p{N}]/u.test(word));
  const letter = word => [...word.replace(/^[^\p{L}\p{N}]+/u, "")][0] ?? "";
  if (!words.length) {
    return "";
  }
  return (
    letter(words[0]) + (words.length > 1 ? letter(words.at(-1)) : "")
  ).toUpperCase();
}

function hue(text) {
  let hash = 0;
  for (const char of text.toLowerCase()) {
    hash = (hash * 31 + char.codePointAt(0)) >>> 0;
  }
  return String(hash % 360);
}

// news.plugin-alliance.com -> plugin-alliance.com: logos belong to the
// organization, and the service never sees more of the address than that.
function orgDomain(email) {
  const host = email.split("@")[1]?.toLowerCase();
  if (!host) {
    return "";
  }
  try {
    return Services.eTLD.getBaseDomainFromHost(host);
  } catch {
    return host;
  }
}
