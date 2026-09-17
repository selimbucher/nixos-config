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

// Which look of message-list.css to use; it's set as data-ml-variant on
// about:3pane's root, so switching it in the Config Editor applies live.
var VARIANT_PREF = "extensions.message-list.variant";
// Logo service base URL, e.g. "https://logos.selim.one/" (see
// ~/Documents/Code/mail-logos); the sender's organizational domain is
// appended. Empty shows initials only.
var LOGO_PREF = "extensions.message-list.logoBaseURL";

var messageList = class extends ExtensionCommon.ExtensionAPI {
  onStartup() {
    // about:3pane window -> function undoing its patches
    this.windows = new Map();
    Services.obs.addObserver(this, "chrome-document-loaded");
    Services.prefs.addObserver(VARIANT_PREF, this);
    Services.prefs.addObserver(LOGO_PREF, this);
    for (const win of Services.wm.getEnumerator("mail:3pane")) {
      for (const tab of win.gTabmail?.tabInfo ?? []) {
        const about3Pane = tab.chromeBrowser?.contentWindow;
        if (about3Pane?.location.href == "about:3pane") {
          this.attach(about3Pane);
        }
      }
    }
  }

  onShutdown(isAppShutdown) {
    if (isAppShutdown) {
      return;
    }
    Services.obs.removeObserver(this, "chrome-document-loaded");
    Services.prefs.removeObserver(VARIANT_PREF, this);
    Services.prefs.removeObserver(LOGO_PREF, this);
    for (const detach of this.windows.values()) {
      detach?.();
    }
    this.windows.clear();
  }

  observe(subject, topic, data) {
    if (topic == "chrome-document-loaded") {
      if (subject.documentURI == "about:3pane") {
        this.attach(subject.defaultView);
      }
      return;
    }
    for (const about3Pane of this.windows.keys()) {
      if (data == VARIANT_PREF) {
        this.applyVariant(about3Pane);
      } else {
        about3Pane.threadTree?.invalidate();
      }
    }
  }

  async attach(about3Pane) {
    if (this.windows.has(about3Pane)) {
      return;
    }
    this.windows.set(about3Pane, null);
    about3Pane.addEventListener(
      "unload",
      () => this.windows.delete(about3Pane),
      { once: true }
    );
    await about3Pane.customElements.whenDefined("thread-card");
    if (!this.windows.has(about3Pane)) {
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

    this.windows.set(about3Pane, () => {
      ThreadCard.prototype.fillRow = fillRow;
      threadPane.densityChange = densityChange;
      for (const badge of about3Pane.document.querySelectorAll(".ml-badge")) {
        badge.remove();
      }
      delete about3Pane.document.documentElement.dataset.mlVariant;
      threadPane.updateThreadItemSize();
    });
    this.applyVariant(about3Pane);
  }

  applyVariant(about3Pane) {
    about3Pane.document.documentElement.dataset.mlVariant =
      Services.prefs.getStringPref(VARIANT_PREF, "mail");
    // Recomputes the row height from the new variant's CSS and refills rows.
    about3Pane.threadPane.updateThreadItemSize();
  }

  getAPI() {
    return { messageList: {} };
  }
};

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
  const email = person.email ?? "";
  badge.querySelector(".ml-initials").textContent = initials(
    person.name,
    email
  );
  badge.style.setProperty("--ml-hue", hue(email || person.name || ""));

  const base = Services.prefs.getStringPref(LOGO_PREF, "");
  const domain = orgDomain(email);
  const logoURL = base && domain ? base + encodeURIComponent(domain) : "";
  if (badge.dataset.logoUrl != logoURL) {
    badge.dataset.logoUrl = logoURL;
    if (logos.has(logoURL)) {
      // Already fetched: no flash of initials while scrolling.
      showLogo(badge, logos.get(logoURL));
    } else {
      showLogo(badge, null);
      if (logoURL) {
        fetchLogo(logoURL).then(dataURL => {
          // Only if the row still shows a message from that domain.
          if (badge.dataset.logoUrl == logoURL) {
            showLogo(badge, dataURL);
          }
        });
      }
    }
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

// logo URL -> data: URL, or null when the service has no logo
var logos = new Map();
// logo URL -> pending fetch
var logoFetches = new Map();

// about:3pane's CSP only allows data: images, so logos are fetched here, with
// the system principal, and handed over as data: URLs. The HTTP cache keeps
// them across restarts (the service sends Cache-Control).
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
