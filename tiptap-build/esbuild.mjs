// esbuild.mjs
//
// Bundles src/editor.js and every Tiptap dependency into a single
// self-contained file at:
//   ../Lurelia/Resources/TiptapEditor/tiptap.bundle.js
//
// This build script lives at repo root (../tiptap-build) so Xcode's
// folder-reference on Resources/TiptapEditor never sweeps it into the
// app bundle. Only the produced tiptap.bundle.js and the HTML shell
// get shipped.
//
// Usage:
//   cd tiptap-build
//   npm install
//   npm run build     # one-shot bundle
//   npm run watch     # rebuild on save

import esbuild from "esbuild";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const outFile = resolve(
  __dirname,
  "..",
  "Lurelia",
  "Resources",
  "TiptapEditor",
  "tiptap.bundle.js",
);

const isWatch = process.argv.includes("--watch");

const options = {
  entryPoints: [resolve(__dirname, "src", "editor.js")],
  outfile: outFile,
  bundle: true,
  minify: true,
  sourcemap: false,
  format: "iife",
  target: ["safari15"],
  logLevel: "info",
  banner: {
    js: "/* Lurelia Tiptap bundle. Regenerate with `npm run build` from ../tiptap-build. */",
  },
};

if (isWatch) {
  const ctx = await esbuild.context(options);
  await ctx.watch();
  console.log("[tiptap] watching for changes…");
} else {
  await esbuild.build(options);
  console.log(`[tiptap] wrote ${outFile}`);
}
