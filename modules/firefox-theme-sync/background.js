"use strict";

const DARK = "{0e5c8ff0-b54b-4bd1-b33e-d5e016e066f0}";
const LIGHT = "{08400cc9-1bf6-4e3e-b175-2d2650bc3104}";

async function applyMode(mode) {
  const target = mode === "light" ? LIGHT : DARK;
  try {
    const info = await browser.management.get(target);
    if (!info.enabled) {
      await browser.management.setEnabled(target, true);
      console.log(`everforest-sync: enabled ${mode} theme`);
    }
  } catch (error) {
    console.error("everforest-sync: cannot switch theme", error);
  }
}

function connect() {
  let port;
  try {
    port = browser.runtime.connectNative("everforest_sync");
  } catch (error) {
    console.error("everforest-sync: native host unavailable", error);
    setTimeout(connect, 3000);
    return;
  }

  port.onMessage.addListener((message) => {
    if (message && (message.mode === "dark" || message.mode === "light")) {
      applyMode(message.mode);
    }
  });

  port.onDisconnect.addListener(() => {
    // Noctalia/Firefox may restart the host; reconnect quietly.
    setTimeout(connect, 3000);
  });
}

connect();
