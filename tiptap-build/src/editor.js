// src/editor.js
//
// Bundle entry. Output → ../Lurelia/Resources/TiptapEditor/tiptap.bundle.js
//
// Bridge:
//   Swift → JS   window.tiptapCommand(name, args)
//   JS → Swift   webkit.messageHandlers.tiptap.postMessage({kind, payload})

import { Editor, Node, mergeAttributes } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";
import Image from "@tiptap/extension-image";
import Link from "@tiptap/extension-link";
import Underline from "@tiptap/extension-underline";
import Placeholder from "@tiptap/extension-placeholder";
import { Markdown } from "tiptap-markdown";

function postToSwift(kind, payload) {
  try {
    window.webkit?.messageHandlers?.tiptap?.postMessage({ kind, payload });
  } catch (_e) {}
}

const lureliaIconAssets = new Map();

function iconSource(icon, color = "#FFFFFF", size = 22) {
  const cleanIcon = String(icon || "starcal").trim() || "starcal";
  const registeredSource = lureliaIconAssets.get(cleanIcon);
  if (registeredSource) return registeredSource;

  const params = new URLSearchParams({
    color: String(color || "#FFFFFF"),
    size: String(size || 22),
  });
  return `lurelia-icon://asset/${encodeURIComponent(cleanIcon)}?${params.toString()}`;
}

function renderCalloutIcons(root = document) {
  root.querySelectorAll?.(".callout").forEach((callout) => {
    const icon = callout.dataset.icon || "starcal";
    const iconView = callout.querySelector(".callout-icon-image");
    if (!iconView) return;
    iconView.setAttribute("aria-label", icon);
    iconView.dataset.lureliaIcon = icon;
    iconView.style.backgroundImage = `url("${iconSource(icon, "#FFFFFF", 22)}")`;
    iconView.hidden = false;
  });
}

// ────────────────────────────────────────────────────────────────────────
// Callout — a real ProseMirror node so the schema preserves
// <div class="callout"> during editing and HTML export. The icon URL is emitted
// directly from renderHTML so ProseMirror redraws keep the image source intact.
// ────────────────────────────────────────────────────────────────────────

const Callout = Node.create({
  name: "callout",
  group: "block",
  content: "block+",
  defining: true,
  isolating: true,

  addAttributes() {
    return {
      icon: {
        default: "starcal",
        parseHTML: (el) => el.getAttribute("data-icon") || "starcal",
        renderHTML: (attrs) => ({ "data-icon": attrs.icon }),
      },
      calloutId: {
        default: null,
        parseHTML: (el) => el.getAttribute("data-callout-id"),
        renderHTML: (attrs) =>
          attrs.calloutId ? { "data-callout-id": attrs.calloutId } : {},
      },
    };
  },

  parseHTML() {
    return [
      { tag: 'div[data-type="lurelia-callout"]' },
      { tag: "div.callout" },
    ];
  },

  renderHTML({ HTMLAttributes, node }) {
    const icon = node.attrs.icon || "starcal";
    const calloutId = node.attrs.calloutId;
    const attrs = {
      "data-type": "lurelia-callout",
      class: "callout",
      "data-icon": icon,
    };
    if (calloutId) attrs["data-callout-id"] = calloutId;
    return [
      "div",
      mergeAttributes(HTMLAttributes, attrs),
      [
        "span",
        {
          class: "callout-icon-button",
          contenteditable: "false",
          "data-callout-icon-button": "true",
          role: "button",
          tabindex: "0",
          "aria-label": "Change callout icon",
        },
        [
          "span",
          {
            class: "callout-icon-image",
            role: "img",
            "aria-label": icon,
            style: `background-image: url("${iconSource(icon, "#FFFFFF", 22)}")`,
          },
        ],
      ],
      ["div", { class: "callout-content" }, 0],
    ];
  },

  addCommands() {
    return {
      insertLureliaCallout:
        (attrs = {}) =>
        ({ commands, state }) => {
          const icon = attrs.icon || "starcal";
          const text = (attrs.text || "").trim() || "Callout text";
          const callout = {
            type: "callout",
            attrs: {
              icon,
              calloutId: "cid-" + Math.random().toString(36).slice(2, 10),
            },
            content: [
              {
                type: "paragraph",
                content: text ? [{ type: "text", text }] : [],
              },
            ],
          };
          return commands.insertContentAt(
            { from: state.selection.from, to: state.selection.to },
            callout,
            { updateSelection: true },
          );
        },
      updateLureliaCalloutIcon:
        (icon) =>
        ({ tr, state, dispatch }) => {
          const { doc } = state;
          let foundPos = -1;
          doc.descendants((n, pos) => {
            if (n.type.name === "callout" && foundPos === -1) {
              const sel = state.selection;
              if (pos <= sel.from && sel.from <= pos + n.nodeSize) {
                foundPos = pos;
                return false;
              }
            }
            return true;
          });
          if (foundPos < 0) return false;
          if (dispatch) {
            const node = doc.nodeAt(foundPos);
            tr.setNodeMarkup(foundPos, undefined, {
              ...node.attrs,
              icon,
            });
            dispatch(tr);
          }
          return true;
        },
    };
  },

  addStorage() {
    return {
      markdown: {
        serialize(state, node) {
          const icon = String(node.attrs.icon || "starcal").replace(/"/g, "");
          const calloutId = String(node.attrs.calloutId || "").replace(/"/g, "");
          state.write(`:::lurelia-callout icon="${icon}" id="${calloutId}"\n`);
          state.renderContent(node);
          state.ensureNewLine();
          state.write(":::");
          state.closeBlock(node);
        },
        parse: {},
      },
    };
  },
});

function htmlEscape(text) {
  return String(text ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function markdownCalloutsToEditorHTML(markdown) {
  const source = String(markdown ?? "");
  return source.replace(
    /:::lurelia-callout(?:\s+icon="([^"]*)")?(?:\s+id="([^"]*)")?\s*\n([\s\S]*?)\n:::/g,
    (_match, icon, id, body) => {
      const safeIcon = htmlEscape(icon || "starcal");
      const safeId = htmlEscape(id || "cid-" + Math.random().toString(36).slice(2, 10));
      const paragraphs = String(body || "")
        .split(/\n{2,}/)
        .map((chunk) => chunk.trim())
        .filter(Boolean)
        .map((chunk) => `<p>${htmlEscape(chunk).replace(/\n/g, "<br>")}</p>`)
        .join("");
      return `<div data-type="lurelia-callout" class="callout" data-icon="${safeIcon}" data-callout-id="${safeId}">${paragraphs || "<p></p>"}</div>`;
    },
  );
}

// ────────────────────────────────────────────────────────────────────────
// Toolbar state + helpers
// ────────────────────────────────────────────────────────────────────────

function toolbarState(editor) {
  return {
    isBold: editor.isActive("bold"),
    isItalic: editor.isActive("italic"),
    isUnderline: editor.isActive("underline"),
    isStrike: editor.isActive("strike"),
    isCode: editor.isActive("code"),
    isBlockquote: editor.isActive("blockquote"),
    isCodeBlock: editor.isActive("codeBlock"),
    isBulletList: editor.isActive("bulletList"),
    isOrderedList: editor.isActive("orderedList"),
    isLink: editor.isActive("link"),
    isH1: editor.isActive("heading", { level: 1 }),
    isH2: editor.isActive("heading", { level: 2 }),
    isH3: editor.isActive("heading", { level: 3 }),
    canUndo: editor.can().undo(),
    canRedo: editor.can().redo(),
  };
}

function escapeMarkdownText(text) {
  return String(text ?? "");
}

function serializeInline(nodes = []) {
  return nodes.map(serializeNode).join("");
}

function serializeChildren(node, separator = "\n\n") {
  return (node.content || [])
    .map(serializeNode)
    .filter((part) => part.trim().length > 0)
    .join(separator);
}

function serializeNode(node, listIndex = 1) {
  if (!node) return "";

  switch (node.type) {
    case "doc":
      return serializeChildren(node).trim();
    case "text": {
      let text = escapeMarkdownText(node.text || "");
      for (const mark of node.marks || []) {
        switch (mark.type) {
          case "bold":
            text = `**${text}**`;
            break;
          case "italic":
            text = `_${text}_`;
            break;
          case "strike":
            text = `~~${text}~~`;
            break;
          case "code":
            text = `\`${text}\``;
            break;
          case "link": {
            const href = mark.attrs?.href || "";
            if (href) text = `[${text}](${href})`;
            break;
          }
          default:
            break;
        }
      }
      return text;
    }
    case "paragraph":
      return serializeInline(node.content || []);
    case "heading": {
      const level = Math.max(1, Math.min(3, Number(node.attrs?.level) || 1));
      return `${"#".repeat(level)} ${serializeInline(node.content || [])}`;
    }
    case "blockquote":
      return serializeChildren(node)
        .split("\n")
        .map((line) => `> ${line}`)
        .join("\n");
    case "bulletList":
      return (node.content || [])
        .map((child) => `- ${serializeNode(child).replace(/\n/g, "\n  ")}`)
        .join("\n");
    case "orderedList":
      return (node.content || [])
        .map((child, index) => {
          const number = Number(node.attrs?.start || 1) + index;
          return `${number}. ${serializeNode(child, number).replace(/\n/g, "\n   ")}`;
        })
        .join("\n");
    case "listItem":
      return serializeChildren(node, "\n");
    case "codeBlock":
      return "```\n" + serializeInline(node.content || []) + "\n```";
    case "hardBreak":
      return "\n";
    case "image": {
      const alt = node.attrs?.alt || "";
      const src = node.attrs?.src || "";
      return src ? `![${alt}](${src})` : "";
    }
    case "callout": {
      const icon = String(node.attrs?.icon || "starcal").replace(/"/g, "");
      const calloutId = String(node.attrs?.calloutId || "").replace(/"/g, "");
      const body = serializeChildren(node).trim() || "Callout text";
      return `:::lurelia-callout icon="${icon}" id="${calloutId}"\n${body}\n:::`;
    }
    default:
      return serializeChildren(node);
  }
}

function lureliaMarkdown(editor) {
  const json = editor.getJSON();
  return serializeNode(json).trim();
}

function editorSnapshot(editor) {
  const markdown = lureliaMarkdown(editor);
  return {
    markdown,
    html: editor.getHTML(),
    isEmpty: editor.isEmpty,
  };
}

const editor = new Editor({
  element: document.getElementById("editor"),
  extensions: [
    StarterKit.configure({ heading: { levels: [1, 2, 3] } }),
    Image.configure({ inline: false, allowBase64: false }),
    Link.configure({ openOnClick: false, autolink: true }),
    Underline,
    Placeholder.configure({
      placeholder: "Write a post for your event…",
    }),
    Callout,
    Markdown.configure({
      html: true,
      breaks: true,
      linkify: true,
      transformPastedText: true,
      transformCopiedText: true,
    }),
  ],
  content: "",
  autofocus: false,
  onUpdate: ({ editor }) => {
    renderCalloutIcons();
    postToSwift("update", editorSnapshot(editor));
  },
  onSelectionUpdate: ({ editor }) => {
    postToSwift("selectionChange", toolbarState(editor));
  },
  onFocus: () => postToSwift("focus", {}),
  onBlur: () => postToSwift("blur", {}),
});

document.addEventListener("mousedown", (evt) => {
  const iconButton = evt.target.closest?.(".callout-icon-button");
  if (!iconButton) return;
  evt.preventDefault();
});

document.addEventListener("click", (evt) => {
  const iconButton = evt.target.closest?.(".callout-icon-button");
  if (!iconButton) return;
  const calloutTarget = iconButton.closest(".callout");
  if (!calloutTarget) return;
  evt.preventDefault();
  evt.stopPropagation();
  postToSwift("iconPickerRequest", {
    calloutId: calloutTarget.dataset.calloutId || "",
    currentIcon: calloutTarget.dataset.icon || "starcal",
  });
});

// ────────────────────────────────────────────────────────────────────────
// Public API (Swift → JS)
// ────────────────────────────────────────────────────────────────────────

window.tiptapCommand = function tiptapCommand(name, args) {
  const a = args || {};
  const c = editor.chain().focus();
  switch (name) {
    case "setContent":
      editor.commands.setContent(markdownCalloutsToEditorHTML(a.markdown), true);
      renderCalloutIcons();
      return true;
    case "getMarkdown":
      return editorSnapshot(editor).markdown;
    case "getHTML":
      return editor.getHTML();
    case "toggleBold":
      return c.toggleBold().run();
    case "toggleItalic":
      return c.toggleItalic().run();
    case "toggleUnderline":
      return c.toggleUnderline().run();
    case "toggleStrike":
      return c.toggleStrike().run();
    case "toggleCode":
      return c.toggleCode().run();
    case "toggleBlockquote":
      return c.toggleBlockquote().run();
    case "toggleCodeBlock":
      return c.toggleCodeBlock().run();
    case "toggleBulletList":
      return c.toggleBulletList().run();
    case "toggleOrderedList":
      return c.toggleOrderedList().run();
    case "setHeading":
      return c
        .toggleHeading({ level: Math.max(1, Math.min(3, Number(a.level) || 1)) })
        .run();
    case "clearFormatting":
      return c.clearNodes().unsetAllMarks().run();
    case "setLink": {
      const href = String(a.href ?? "").trim();
      if (!href) return c.unsetLink().run();
      return c
        .extendMarkRange("link")
        .setLink({ href, target: "_blank", rel: "noopener nofollow" })
        .run();
    }
    case "unsetLink":
      return c.unsetLink().run();
    case "insertCallout": {
      const icon = String(a.icon ?? "starcal");
      const text = String(a.text ?? "");
      return c.insertLureliaCallout({ icon, text }).run();
    }
    case "updateCalloutIcon": {
      // Find the callout matching the calloutId (or fall back to the one
      // containing the current selection).
      const icon = String(a.icon ?? "").trim();
      const calloutId = String(a.calloutId ?? "").trim();
      if (!icon) return false;

      if (calloutId) {
        // Locate the callout by id and setNodeMarkup at that pos.
        const { state, view } = editor;
        let foundPos = -1;
        state.doc.descendants((n, pos) => {
          if (
            n.type.name === "callout" &&
            n.attrs.calloutId === calloutId &&
            foundPos === -1
          ) {
            foundPos = pos;
            return false;
          }
          return true;
        });
        if (foundPos < 0) return false;
        const node = state.doc.nodeAt(foundPos);
        const tr = state.tr.setNodeMarkup(foundPos, undefined, {
          ...node.attrs,
          icon,
        });
        view.dispatch(tr);
        renderCalloutIcons();
        postToSwift("update", editorSnapshot(editor));
        return true;
      }

      // Fallback: update the callout containing the current selection.
      {
        const didUpdate = c.updateLureliaCalloutIcon(icon).run();
        renderCalloutIcons();
        if (didUpdate) postToSwift("update", editorSnapshot(editor));
        return didUpdate;
      }
    }
    case "registerIconAsset": {
      const icon = String(a.icon ?? "").trim();
      const src = String(a.src ?? "").trim();
      if (!icon || !src) return false;
      lureliaIconAssets.set(icon, src);
      renderCalloutIcons();
      return true;
    }
    case "insertImage": {
      const src = String(a.url ?? "").trim();
      if (!src) return false;
      return c
        .setImage({ src, alt: String(a.alt ?? "") })
        .createParagraphNear()
        .run();
    }
    case "insertFileLink": {
      const href = String(a.url ?? "").trim();
      const label = String(a.filename ?? "").trim() || "File";
      if (!href) return false;
      return c
        .insertContent(
          '<p><a class="file-chip" href="' +
            href +
            '" target="_blank" rel="noopener">' +
            label.replace(/[<>&"']/g, "") +
            "</a></p>",
        )
        .run();
    }
    case "undo":
      return c.undo().run();
    case "redo":
      return c.redo().run();
    case "focus":
      editor.commands.focus("end");
      return true;
    case "blur":
      editor.commands.blur();
      return true;
    default:
      return false;
  }
};

window.tiptapRequestImage = () => postToSwift("imageRequest", {});
window.tiptapRequestFile = () => postToSwift("fileRequest", {});
window.tiptapRequestLink = () =>
  postToSwift("linkRequest", {
    currentHref: editor.getAttributes("link").href ?? "",
  });

postToSwift("ready", { toolbar: toolbarState(editor) });
