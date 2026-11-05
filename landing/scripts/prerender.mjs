#!/usr/bin/env node
// Prerender the landing page into dist/client/index.html so crawlers get the
// full text and H1 without running JavaScript. The client still mounts with
// createRoot, which replaces this markup with the live app.
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import React from "react";
import { renderToString } from "react-dom/server";
import { createServer } from "vite";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const index = path.join(root, "dist", "client", "index.html");
const placeholder = '<div id="root"></div>';

const vite = await createServer({
  root,
  configFile: path.join(root, "vite.config.mjs"),
  logLevel: "error",
  appType: "custom",
  optimizeDeps: { noDiscovery: true, include: [] },
  server: { middlewareMode: true, hmr: false, warmup: { clientFiles: [] } },
});

try {
  const { App } = await vite.ssrLoadModule("/src/App.jsx");
  const markup = renderToString(React.createElement(App));
  if (!markup.includes("<h1")) throw new Error("Prerendered markup has no <h1>");

  const html = readFileSync(index, "utf8");
  if (!html.includes(placeholder)) throw new Error("Missing " + placeholder + " in " + index);
  writeFileSync(index, html.replace(placeholder, `<div id="root">${markup}</div>`));
  console.log(`Prerendered ${markup.length} chars into dist/client/index.html`);
} finally {
  await vite.close();
}
