"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const stateFile = path.join(
  os.homedir(),
  ".local",
  "state",
  "noctalia",
  "theme-mode",
);

function readMode() {
  try {
    const mode = fs.readFileSync(stateFile, "utf8").trim();
    return mode === "light" ? "light" : "dark";
  } catch {
    return "dark";
  }
}

function send(message) {
  const body = Buffer.from(JSON.stringify(message));
  const header = Buffer.alloc(4);
  header.writeUInt32LE(body.length, 0);
  process.stdout.write(Buffer.concat([header, body]));
}

function sendMode() {
  send({ mode: readMode() });
}

sendMode();

try {
  fs.watch(path.dirname(stateFile), (event, filename) => {
    if (filename === "theme-mode") {
      sendMode();
    }
  });
} catch (error) {
  // If the directory does not exist yet, the next Noctalia start will create
  // it; the browser reconnect will pick the mode up then.
  console.error("everforest-sync-host: watch failed", error);
}

// Keep the host alive for the lifetime of the browser's native port.
process.stdin.on("data", () => {});
process.stdin.on("end", () => process.exit(0));
process.stdin.resume();
