(function () {
  "use strict";

  const BASE = (document.querySelector('meta[name="rhl-base"]') || {}).content || "";
  const CSRF = (document.querySelector('meta[name="csrf-token"]') || {}).content || "";
  const API  = (p) => `${BASE}/api${p}`;
  const VERBS = ["get","post","put","patch","delete","head","options"];

  // Body type → block name suffix (Bruno format)
  const BODY_BLOCK = {
    json:            "body:json",
    text:            "body:text",
    xml:             "body:xml",
    graphql:         "body:graphql",
    sparql:          "body:sparql",
    formUrlEncoded:  "body:form-urlencoded",
    multipartForm:   "body:multipart-form",
    file:            "body:file"
  };
  const BODY_KINDS_RAW = ["json", "text", "xml", "graphql", "sparql"];
  const BODY_KINDS_KV  = ["formUrlEncoded", "multipartForm"];
  const BODY_KINDS_ALL = ["none", ...BODY_KINDS_RAW, ...BODY_KINDS_KV];

  // HTTP reason phrases (RFC 9110 + common extensions).
  const STATUS_TEXT = {
    100: "Continue", 101: "Switching Protocols", 102: "Processing", 103: "Early Hints",
    200: "OK", 201: "Created", 202: "Accepted", 203: "Non-Authoritative Information",
    204: "No Content", 205: "Reset Content", 206: "Partial Content", 207: "Multi-Status",
    208: "Already Reported", 226: "IM Used",
    300: "Multiple Choices", 301: "Moved Permanently", 302: "Found", 303: "See Other",
    304: "Not Modified", 307: "Temporary Redirect", 308: "Permanent Redirect",
    400: "Bad Request", 401: "Unauthorized", 402: "Payment Required", 403: "Forbidden",
    404: "Not Found", 405: "Method Not Allowed", 406: "Not Acceptable",
    407: "Proxy Authentication Required", 408: "Request Timeout", 409: "Conflict",
    410: "Gone", 411: "Length Required", 412: "Precondition Failed",
    413: "Payload Too Large", 414: "URI Too Long", 415: "Unsupported Media Type",
    416: "Range Not Satisfiable", 417: "Expectation Failed", 418: "I'm a teapot",
    421: "Misdirected Request", 422: "Unprocessable Entity", 423: "Locked",
    424: "Failed Dependency", 425: "Too Early", 426: "Upgrade Required",
    428: "Precondition Required", 429: "Too Many Requests",
    431: "Request Header Fields Too Large", 451: "Unavailable For Legal Reasons",
    500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway",
    503: "Service Unavailable", 504: "Gateway Timeout", 505: "HTTP Version Not Supported",
    506: "Variant Also Negotiates", 507: "Insufficient Storage", 508: "Loop Detected",
    510: "Not Extended", 511: "Network Authentication Required"
  };

  // ---------- State ----------
  // One *session* per request path holds the working doc (with unsaved edits),
  // the last /run response, and which tabs were open — so navigating between
  // requests never loses data. Sessions are mirrored to localStorage so they
  // also survive a page reload (see persistSessions/hydrateSessions).
  const state = {
    tree: null,
    currentKey: null,          // active request path == session map key
    envName: "",
    expandedFolders: new Set(),
    sessions: new Map(),       // path -> session
  };

  // localStorage config
  const LS_KEY = `rhl:${BASE || "/"}:sessions`;
  const LS_MAX_SESSIONS = 30;          // LRU cap
  const LS_MAX_BODY = 200 * 1024;      // per-response body cap for persistence
  let hydratedKey = null;              // currentKey restored from storage

  function makeSession(path, doc) {
    return {
      path,
      doc,
      savedDoc: cloneDoc(doc),   // last on-disk version, for dirty detection
      activeTab: "params",
      responseTab: "body",
      response: null,            // last /run result, or { error }
      touched: Date.now(),
      _wasDirty: false,
    };
  }
  function activeSession() { return state.currentKey ? (state.sessions.get(state.currentKey) || null) : null; }
  function currentDoc() { return activeSession()?.doc || null; }
  function cloneDoc(doc) { return doc ? JSON.parse(JSON.stringify(doc)) : doc; }

  // Dirty = working doc differs from the saved version, comparing *normalized*
  // sources so that merely viewing a tab (which lazily injects an empty block)
  // or leaving a blank "+ Add row" doesn't count as a change.
  function normalizedSource(doc) {
    if (!doc) return "";
    const blocks = (doc.blocks || []).filter((b) => {
      if (b.mode === "raw") return (b.raw || "").trim() !== "";
      const pairs = (b.pairs || []).filter(([k, v]) =>
        (k || "").trim() !== "" || (v || "").trim() !== "");
      return pairs.length > 0;
    });
    return serializeDoc({ blocks });
  }
  function isDirty(session) {
    if (!session) return false;
    return normalizedSource(session.doc) !== normalizedSource(session.savedDoc);
  }

  function ensureExpanded(path) {
    if (!path) return;
    const parts = path.split("/");
    let cur = "";
    for (const part of parts) {
      cur = cur ? `${cur}/${part}` : part;
      state.expandedFolders.add(cur);
    }
  }
  function parentDir(path) {
    if (!path) return "";
    const i = path.lastIndexOf("/");
    return i < 0 ? "" : path.slice(0, i);
  }

  // ---------- Helpers ----------
  const $  = (sel) => document.querySelector(sel);
  const ce = (tag, attrs = {}, ...children) => {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (k === "class")       el.className = v;
      else if (k === "dataset") Object.assign(el.dataset, v);
      else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
      else if (v === true)     el.setAttribute(k, "");
      else if (v !== false && v != null) el.setAttribute(k, v);
    }
    for (const c of children) {
      if (c == null) continue;
      el.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
    }
    return el;
  };

  async function api(method, path, body) {
    const opts = { method, headers: { "Accept": "application/json" } };
    if (body !== undefined) {
      opts.headers["Content-Type"] = "application/json";
      opts.headers["X-CSRF-Token"] = CSRF;
      opts.body = JSON.stringify(body);
    }
    const res = await fetch(API(path), opts);
    if (!res.ok) {
      let detail = "";
      try { detail = (await res.json()).error || ""; } catch (_) {}
      throw new Error(`${res.status} ${res.statusText}${detail ? " — " + detail : ""}`);
    }
    if (res.status === 204) return null;
    return res.json();
  }

  // ---------- Doc utilities ----------
  function findVerbBlock(doc)   { return (doc?.blocks || []).find((b) => VERBS.includes(b.name)); }
  function findBlock(doc, name) { return (doc?.blocks || []).find((b) => b.name === name); }
  function docMethod(doc) { return (findVerbBlock(doc)?.name || "get").toUpperCase(); }
  function docUrl(doc) {
    const v = findVerbBlock(doc);
    return (v && (v.pairs.find(([k]) => k === "url") || [])[1]) || "";
  }

  function ensureKvBlock(name) {
    const doc = currentDoc();
    let b = findBlock(doc, name);
    if (!b) { b = { name, mode: "kv", pairs: [] }; doc.blocks.push(b); }
    if (!Array.isArray(b.pairs)) b.pairs = [];
    return b;
  }
  function ensureRawBlock(name) {
    const doc = currentDoc();
    let b = findBlock(doc, name);
    if (!b) { b = { name, mode: "raw", raw: "" }; doc.blocks.push(b); }
    if (typeof b.raw !== "string") b.raw = "";
    return b;
  }
  function getVerbPair(key) {
    const v = findVerbBlock(currentDoc());
    if (!v) return null;
    return v.pairs.find(([k]) => k === key);
  }
  function setVerbPair(key, value) {
    const doc = currentDoc();
    if (!doc) return;
    let v = findVerbBlock(doc);
    if (!v) {
      v = { name: "get", mode: "kv", pairs: [["url", ""], ["body", "none"], ["auth", "none"]] };
      doc.blocks.push(v);
    }
    const pair = v.pairs.find(([k]) => k === key);
    if (pair) pair[1] = value; else v.pairs.push([key, value]);
  }
  function setVerbName(name) {
    const doc = currentDoc();
    if (!doc) return;
    let v = findVerbBlock(doc);
    if (!v) {
      doc.blocks.push({ name, mode: "kv", pairs: [["url",""],["body","none"],["auth","none"]] });
    } else {
      v.name = name;
    }
  }

  // ---------- .bru source serializer (client-side) ----------
  function serializeDoc(doc) {
    return (doc.blocks || []).map((b) => {
      if (b.mode === "raw") {
        const body = b.raw || "";
        const tail = body.endsWith("\n") || body === "" ? "" : "\n";
        return `${b.name} {\n${body}${tail}}\n`;
      }
      const lines = (b.pairs || []).map(([k, v]) => `  ${k}: ${v}`).join("\n");
      return `${b.name} {\n${lines}${lines ? "\n" : ""}}\n`;
    }).join("\n");
  }

  // ---------- Session persistence (localStorage) ----------
  let persistTimer = null;
  function schedulePersist() {
    if (persistTimer) return;
    persistTimer = setTimeout(() => { persistTimer = null; persistSessions(); }, 400);
  }

  function trimResponseForStorage(resp) {
    if (!resp) return null;
    const body = resp.body != null ? String(resp.body) : resp.body;
    if (body && body.length > LS_MAX_BODY) {
      const copy = { ...resp };
      copy.body = null;
      copy.bodyTruncated = true;
      return copy;
    }
    return resp;
  }

  function persistSessions() {
    try {
      const entries = [...state.sessions.entries()]
        .sort((a, b) => (b[1].touched || 0) - (a[1].touched || 0))
        .slice(0, LS_MAX_SESSIONS);
      const payload = { v: 1, currentKey: state.currentKey, envName: state.envName, sessions: {} };
      for (const [key, s] of entries) {
        payload.sessions[key] = {
          path: s.path,
          doc: s.doc,
          savedDoc: s.savedDoc,
          activeTab: s.activeTab,
          responseTab: s.responseTab,
          touched: s.touched,
          response: trimResponseForStorage(s.response),
        };
      }
      localStorage.setItem(LS_KEY, JSON.stringify(payload));
    } catch (_) {
      // QuotaExceededError or storage disabled — degrade silently.
    }
  }

  function hydrateSessions() {
    try {
      const raw = localStorage.getItem(LS_KEY);
      if (!raw) return;
      const payload = JSON.parse(raw);
      if (!payload || !payload.sessions) return;
      if (payload.envName) state.envName = payload.envName;
      hydratedKey = payload.currentKey || null;
      for (const [key, s] of Object.entries(payload.sessions)) {
        if (!s || !s.doc) continue;
        state.sessions.set(key, {
          path: s.path || key,
          doc: s.doc,
          savedDoc: s.savedDoc || cloneDoc(s.doc),
          activeTab: s.activeTab || "params",
          responseTab: s.responseTab || "body",
          response: s.response || null,
          touched: s.touched || Date.now(),
          _wasDirty: false,
        });
      }
    } catch (_) {}
  }

  function collectRequestPaths(node, acc) {
    for (const c of (node.children || [])) {
      if (c.type === "request") acc.add(c.path);
      else if (c.type === "folder") collectRequestPaths(c, acc);
    }
    return acc;
  }
  // Drop cached sessions whose request no longer exists on disk (deleted
  // externally / in another tab), so stale drafts don't linger.
  function pruneSessions() {
    if (!state.tree) return;
    const valid = collectRequestPaths(state.tree, new Set());
    for (const key of [...state.sessions.keys()]) {
      if (!valid.has(key)) state.sessions.delete(key);
    }
    if (state.currentKey && !state.sessions.has(state.currentKey)) state.currentKey = null;
  }

  function restoreLastSession() {
    if (!hydratedKey) return;
    const s = state.sessions.get(hydratedKey);
    if (!s) return;
    state.currentKey = hydratedKey;
    showEditorForSession(s);
  }

  function clearCache() {
    if (!window.confirm("Clear all locally cached drafts and responses?\nSaved .bru files on disk are NOT affected.")) return;
    state.sessions.clear();
    state.currentKey = null;
    try { localStorage.removeItem(LS_KEY); } catch (_) {}
    $("#rhl-empty").hidden  = false;
    $("#rhl-editor").hidden = true;
    resetResponse();
    updateSaveDirty();
    if (state.tree) renderTree();
  }

  // ---------- Tree (sidebar) ----------
  async function loadTree() {
    state.tree = await api("GET", "/tree");
    renderTree();
    renderEnvSelect();
  }

  function renderTree() {
    const root = $("#rhl-tree");
    const prevScroll = root.scrollTop;
    root.innerHTML = "";
    if (!state.tree || !state.tree.children.length) {
      root.appendChild(ce("div", { class: "rhl-tree-empty" }, "No collections yet. Use + to create one."));
      return;
    }
    for (const child of state.tree.children) root.appendChild(renderNode(child, 0));
    root.scrollTop = prevScroll;
  }

  function renderNode(node, depth) {
    const indent = { style: `padding-left: ${14 + depth * 12}px` };
    if (node.type === "folder") {
      const isOpen = state.expandedFolders.has(node.path);
      const caret = ce("span", { class: "rhl-tree-caret" }, isOpen ? "▾" : "▸");
      const label = ce("span", { class: "rhl-tree-label" }, node.name);
      const actions = ce("button", {
        class: "rhl-tree-action", title: "Folder actions",
        onclick: (e) => { e.stopPropagation(); openFolderMenu(e.currentTarget, node.path); }
      }, "⋯");
      const header = ce("div", { class: "rhl-tree-node is-folder", ...indent }, caret, label, actions);
      const childWrap = ce("div", { class: "rhl-tree-children" });
      childWrap.hidden = !isOpen;
      header.addEventListener("click", () => {
        const nowOpen = !state.expandedFolders.has(node.path);
        if (nowOpen) state.expandedFolders.add(node.path);
        else        state.expandedFolders.delete(node.path);
        caret.textContent = nowOpen ? "▾" : "▸";
        childWrap.hidden = !nowOpen;
      });
      for (const c of node.children || []) childWrap.appendChild(renderNode(c, depth + 1));
      return ce("div", {}, header, childWrap);
    }
    if (node.type === "request") {
      const verb = (node.method || "GET").toUpperCase();
      const badge = ce("span", { class: `rhl-verb-badge ${verb}` }, verb);
      const label = ce("span", { class: "rhl-tree-label" }, node.name);
      const session = state.sessions.get(node.path);
      if (session && isDirty(session)) {
        label.appendChild(ce("span", { class: "rhl-dirty-dot", title: "Unsaved changes" }, "●"));
      }
      const isActive = state.currentKey === node.path;
      const actions = ce("button", {
        class: "rhl-tree-action", title: "Request actions",
        onclick: (e) => { e.stopPropagation(); openRequestMenu(e.currentTarget, node.path); }
      }, "⋯");
      const row = ce("div", {
        class: `rhl-tree-node is-request${isActive ? " is-active" : ""}`,
        ...indent
      }, badge, label, actions);
      row.addEventListener("click", () => openRequest(node.path).catch((e) => showError(e.message)));
      return row;
    }
    return ce("div");
  }

  // ---------- Tree actions (collection / folder / request creation) ----------
  let openMenuEl = null;
  function closeTreeMenu() {
    if (openMenuEl) { openMenuEl.remove(); openMenuEl = null; }
  }

  function openFolderMenu(anchor, folderPath) {
    openMenu(anchor, [
      ["New request",   () => promptNewRequest(folderPath)],
      ["New folder",    () => promptNewFolder(folderPath)],
      ["Rename folder", () => promptRenameFolder(folderPath)],
      ["Delete folder", () => confirmDeleteFolder(folderPath), "rhl-menu__item--danger"],
    ]);
  }

  function openRequestMenu(anchor, requestPath) {
    openMenu(anchor, [
      ["Rename", () => promptRenameRequest(requestPath)],
      ["Delete", () => confirmDeleteRequest(requestPath), "rhl-menu__item--danger"],
    ]);
  }

  function openMenu(anchor, items) {
    closeTreeMenu();
    const rect = anchor.getBoundingClientRect();
    const menu = ce("div", { class: "rhl-menu" });
    menu.style.left = `${Math.round(rect.right + 4)}px`;
    menu.style.top  = `${Math.round(rect.top)}px`;
    for (const [label, onclick, extraClass] of items) {
      menu.appendChild(menuItem(label, () => { closeTreeMenu(); onclick(); }, extraClass));
    }
    document.body.appendChild(menu);
    openMenuEl = menu;
    setTimeout(() => {
      const onDocClick = (e) => {
        if (!menu.contains(e.target)) {
          document.removeEventListener("click", onDocClick, true);
          closeTreeMenu();
        }
      };
      document.addEventListener("click", onDocClick, true);
    }, 0);
  }

  function menuItem(label, onclick, extraClass) {
    const cls = `rhl-menu__item${extraClass ? " " + extraClass : ""}`;
    return ce("button", { class: cls, onclick }, label);
  }

  function sanitizeSegment(name) {
    return name.trim().replace(/[/\\]/g, "_");
  }

  async function promptNewCollection() {
    const name = window.prompt("New collection name");
    if (!name || !name.trim()) return;
    const safe = sanitizeSegment(name);
    try {
      await api("POST", "/folders", { path: safe, name: safe });
      await loadTree();
    } catch (e) { showError(e.message); }
  }

  async function promptNewFolder(parentPath) {
    const label = parentPath ? `New folder inside "${parentPath}"` : "New folder name";
    const name = window.prompt(label);
    if (!name || !name.trim()) return;
    const safe = sanitizeSegment(name);
    const rel  = parentPath ? `${parentPath}/${safe}` : safe;
    try {
      await api("POST", "/folders", { path: rel, name: safe });
      ensureExpanded(parentPath);
      await loadTree();
    } catch (e) { showError(e.message); }
  }

  async function promptNewRequest(folderPath) {
    const label = folderPath ? `New request inside "${folderPath}" (without .bru)` : "New request name (without .bru)";
    const name = window.prompt(label);
    if (!name || !name.trim()) return;
    const safe = sanitizeSegment(name).replace(/\.bru$/i, "");
    const rel  = (folderPath ? `${folderPath}/` : "") + `${safe}.bru`;
    const doc  = { blocks: [
      { name: "meta", mode: "kv", pairs: [["name", safe], ["type", "http"], ["seq", "1"]] },
      { name: "get",  mode: "kv", pairs: [["url", "https://example.com"], ["body", "none"], ["auth", "none"]] }
    ]};
    try {
      await api("POST", "/requests", { path: rel, source: serializeDoc(doc) });
      ensureExpanded(folderPath);
      await loadTree();
      await openRequest(rel);
    } catch (e) { showError(e.message); }
  }

  async function promptRenameFolder(folderPath) {
    const currentName = folderPath.split("/").pop();
    const next = window.prompt(`Rename folder "${currentName}" to:`, currentName);
    if (next == null) return;
    const trimmed = next.trim();
    if (!trimmed || trimmed === currentName) return;
    const safe = sanitizeSegment(trimmed);
    try {
      const resp    = await api("POST", "/folders/rename", { path: folderPath, name: safe });
      const newPath = resp.path || joinPath(parentDir(folderPath), safe);
      migrateExpandedPath(folderPath, newPath);
      migrateSessionSubtree(folderPath, newPath);
      await loadTree();
      schedulePersist();
    } catch (e) { showError(e.message); }
  }

  async function confirmDeleteFolder(folderPath) {
    if (!window.confirm(`Delete folder "${folderPath}" and all its contents? This cannot be undone.`)) return;
    try {
      await api("DELETE", `/folders/${encodePath(folderPath)}`);
      forgetExpandedSubtree(folderPath);
      forgetSessionSubtree(folderPath);
      if (state.currentKey && pathInsideOrEqual(state.currentKey, folderPath)) {
        closeCurrentRequest();
      }
      await loadTree();
      schedulePersist();
    } catch (e) { showError(e.message); }
  }

  async function promptRenameRequest(requestPath) {
    const currentName = requestPath.split("/").pop().replace(/\.bru$/i, "");
    const next = window.prompt(`Rename request "${currentName}" to:`, currentName);
    if (next == null) return;
    const trimmed = next.trim();
    if (!trimmed || trimmed === currentName) return;
    const safe = sanitizeSegment(trimmed).replace(/\.bru$/i, "");
    try {
      const resp    = await api("POST", "/requests/rename", { path: requestPath, name: safe });
      const newPath = resp.path || joinPath(parentDir(requestPath), `${safe}.bru`);
      migrateSessionKey(requestPath, newPath);
      if (state.currentKey === requestPath) state.currentKey = newPath;
      await loadTree();
      schedulePersist();
    } catch (e) { showError(e.message); }
  }

  async function confirmDeleteRequest(requestPath) {
    if (!window.confirm(`Delete request "${requestPath}"? This cannot be undone.`)) return;
    try {
      await api("DELETE", `/requests/${encodePath(requestPath)}`);
      state.sessions.delete(requestPath);
      if (state.currentKey === requestPath) closeCurrentRequest();
      await loadTree();
      schedulePersist();
    } catch (e) { showError(e.message); }
  }

  function joinPath(parent, child) {
    return parent ? `${parent}/${child}` : child;
  }
  function pathInsideOrEqual(p, prefix) {
    return p === prefix || p.startsWith(prefix + "/");
  }
  function migrateExpandedPath(oldPath, newPath) {
    const updated = new Set();
    for (const p of state.expandedFolders) {
      if (p === oldPath)                       updated.add(newPath);
      else if (p.startsWith(oldPath + "/"))    updated.add(newPath + p.slice(oldPath.length));
      else                                     updated.add(p);
    }
    state.expandedFolders = updated;
  }
  function forgetExpandedSubtree(folderPath) {
    for (const p of [...state.expandedFolders]) {
      if (pathInsideOrEqual(p, folderPath)) state.expandedFolders.delete(p);
    }
  }
  function migrateSessionKey(oldPath, newPath) {
    const s = state.sessions.get(oldPath);
    if (!s) return;
    state.sessions.delete(oldPath);
    s.path = newPath;
    state.sessions.set(newPath, s);
  }
  function migrateSessionSubtree(oldPrefix, newPrefix) {
    for (const key of [...state.sessions.keys()]) {
      if (key === oldPrefix || key.startsWith(oldPrefix + "/")) {
        const s = state.sessions.get(key);
        state.sessions.delete(key);
        const nk = newPrefix + key.slice(oldPrefix.length);
        s.path = nk;
        state.sessions.set(nk, s);
        if (state.currentKey === key) state.currentKey = nk;
      }
    }
  }
  function forgetSessionSubtree(folderPath) {
    for (const key of [...state.sessions.keys()]) {
      if (pathInsideOrEqual(key, folderPath)) state.sessions.delete(key);
    }
  }
  function closeCurrentRequest() {
    state.currentKey = null;
    $("#rhl-empty").hidden  = false;
    $("#rhl-editor").hidden = true;
    resetResponse();
    updateSaveDirty();
    schedulePersist();
  }

  function renderEnvSelect() {
    const sel = $("#rhl-env-select");
    const previousValue = sel.value;
    sel.innerHTML = "";
    sel.appendChild(ce("option", { value: "" }, "(none)"));
    for (const env of (state.tree?.environments || [])) {
      sel.appendChild(ce("option", { value: env.name }, env.name));
    }
    // Restore in priority: explicit state.envName, then whatever the select
    // was showing before (handles browser form-state restoration on reload).
    const candidate = state.envName || previousValue || "";
    const valid = Array.from(sel.options).some((o) => o.value === candidate);
    sel.value = valid ? candidate : "";
    state.envName = sel.value;
  }

  // ---------- Open / render request ----------
  async function openRequest(path) {
    // Persist any in-flight edits of the request we're leaving.
    syncVerbAndUrlIntoDoc();

    let session = state.sessions.get(path);
    if (!session) {
      const doc = await api("GET", `/requests/${encodePath(path)}`);
      session = makeSession(path, doc);
      state.sessions.set(path, session);
    }
    session.touched = Date.now();
    state.currentKey = path;
    showEditorForSession(session);
    schedulePersist();
  }

  // Renders the editor + response area from a session (no network).
  function showEditorForSession(session) {
    $("#rhl-empty").hidden  = true;
    $("#rhl-editor").hidden = false;
    $("#rhl-verb").value = docMethod(session.doc);
    $("#rhl-url").value  = docUrl(session.doc);
    setActiveTab(session.activeTab || "params");
    renderResponseFromSession(session);
    updateSaveDirty();
    if (state.tree) renderTree();
  }

  function renderResponseFromSession(session) {
    if (session.response) {
      showResponse(session.response);
    } else {
      resetResponse();
    }
    setResponseTab(session.responseTab || "body");
  }

  function encodePath(path) {
    return path.split("/").map(encodeURIComponent).join("/");
  }

  // ---------- Tab panel ----------
  function setActiveTab(tab) {
    const s = activeSession();
    if (s) s.activeTab = tab;
    document.querySelectorAll(".rhl-tab").forEach((el) => {
      el.classList.toggle("is-active", el.dataset.tab === tab);
    });
    renderPanel();
  }

  function renderPanel() {
    const panel = $("#rhl-panel");
    panel.innerHTML = "";
    const tab = activeSession()?.activeTab || "params";
    try {
      switch (tab) {
        case "params":  return renderKvTab(panel, "params:query", "Query parameter");
        case "headers": return renderKvTab(panel, "headers",      "Header");
        case "body":    return renderBodyTab(panel);
        case "auth":    return renderAuthTab(panel);
        case "vars":    return renderKvTab(panel, "vars",         "Variable");
        case "script":  return renderReadOnlyRawTab(panel, "script:pre-request",
                          "// no pre-request script set");
        case "tests":   return renderReadOnlyRawTab(panel, "tests",
                          "// no tests defined");
        case "docs":    return renderRawTab(panel, "docs", "Markdown notes…");
      }
    } catch (e) {
      panel.appendChild(ce("div", { class: "rhl-error" }, "UI error: " + e.message));
    }
  }

  function renderKvTab(panel, blockName, placeholder) {
    const block = ensureKvBlock(blockName);
    const table = ce("table", { class: "rhl-kv-table" });
    const thead = ce("thead", {}, ce("tr", {}, ce("th", {}, "Name"), ce("th", {}, "Value"), ce("th", {})));
    const tbody = ce("tbody");
    table.appendChild(thead);
    table.appendChild(tbody);

    block.pairs.forEach((pair, i) => {
      const tr = ce("tr");
      tr.appendChild(ce("td", {}, ce("input", {
        value: pair[0] || "", placeholder,
        oninput: (e) => { block.pairs[i][0] = e.target.value; }
      })));
      tr.appendChild(ce("td", {}, ce("input", {
        value: pair[1] || "", placeholder: "value",
        oninput: (e) => { block.pairs[i][1] = e.target.value; }
      })));
      tr.appendChild(ce("td", { class: "rhl-kv-table__del" }, ce("button", {
        class: "rhl-iconbtn",
        onclick: () => { block.pairs.splice(i, 1); onDocEdited(); renderPanel(); }
      }, "×")));
      tbody.appendChild(tr);
    });

    panel.appendChild(table);
    panel.appendChild(ce("button", {
      class: "rhl-btn rhl-btn--ghost",
      onclick: () => { block.pairs.push(["", ""]); renderPanel(); }
    }, "+ Add row"));
  }

  function renderBodyTab(panel) {
    const currentKind = (getVerbPair("body")?.[1]) || "none";

    const select = ce("select", {
      class: "rhl-select",
      onchange: (e) => { setVerbPair("body", e.target.value); renderPanel(); }
    });
    for (const k of BODY_KINDS_ALL) {
      const opt = ce("option", { value: k }, k);
      if (k === currentKind) opt.setAttribute("selected", "");
      select.appendChild(opt);
    }
    const head = ce("div", { class: "rhl-tab-head" },
      ce("label", { class: "rhl-tab-head__label" }, "Body type:"),
      select
    );
    panel.appendChild(head);

    if (currentKind === "none") {
      panel.appendChild(ce("div", { class: "rhl-hint" }, "No body sent. Choose a type above."));
      return;
    }

    if (BODY_KINDS_KV.includes(currentKind)) {
      const block = ensureKvBlock(BODY_BLOCK[currentKind]);
      const sub = ce("div");
      panel.appendChild(sub);
      renderKvTabInto(sub, block, "field");
      return;
    }

    if (BODY_KINDS_RAW.includes(currentKind)) {
      const block = ensureRawBlock(BODY_BLOCK[currentKind]);
      const ta = ce("textarea", {
        class: "rhl-textarea rhl-textarea--body",
        spellcheck: "false",
        oninput: (e) => { block.raw = e.target.value; }
      });
      ta.value = block.raw || "";
      panel.appendChild(ta);
      if (currentKind === "json") {
        const btn = ce("button", {
          class: "rhl-btn rhl-btn--ghost",
          onclick: () => {
            try {
              const pretty = JSON.stringify(JSON.parse(ta.value), null, 2);
              ta.value = pretty;
              block.raw = pretty;
              onDocEdited();
            } catch (e) { showError("JSON: " + e.message); }
          }
        }, "Prettify");
        panel.appendChild(btn);
      }
      return;
    }

    panel.appendChild(ce("div", { class: "rhl-hint" }, "Body type \"" + currentKind + "\" is preserved but has no inline editor in this version."));
  }

  function renderKvTabInto(container, block, placeholder) {
    const table = ce("table", { class: "rhl-kv-table" });
    const thead = ce("thead", {}, ce("tr", {}, ce("th", {}, "Name"), ce("th", {}, "Value"), ce("th", {})));
    const tbody = ce("tbody");
    table.appendChild(thead); table.appendChild(tbody);
    block.pairs.forEach((pair, i) => {
      const tr = ce("tr");
      tr.appendChild(ce("td", {}, ce("input", {
        value: pair[0] || "", placeholder,
        oninput: (e) => { block.pairs[i][0] = e.target.value; }
      })));
      tr.appendChild(ce("td", {}, ce("input", {
        value: pair[1] || "", placeholder: "value",
        oninput: (e) => { block.pairs[i][1] = e.target.value; }
      })));
      tr.appendChild(ce("td", { class: "rhl-kv-table__del" }, ce("button", {
        class: "rhl-iconbtn",
        onclick: () => { block.pairs.splice(i, 1); onDocEdited(); renderPanel(); }
      }, "×")));
      tbody.appendChild(tr);
    });
    container.appendChild(table);
    container.appendChild(ce("button", {
      class: "rhl-btn rhl-btn--ghost",
      onclick: () => { block.pairs.push(["", ""]); renderPanel(); }
    }, "+ Add row"));
  }

  function renderAuthTab(panel) {
    const kind = (getVerbPair("auth")?.[1]) || "none";
    const select = ce("select", {
      class: "rhl-select",
      onchange: (e) => { setVerbPair("auth", e.target.value); renderPanel(); }
    });
    for (const k of ["none","bearer","basic","apikey","inherit"]) {
      const opt = ce("option", { value: k }, k);
      if (k === kind) opt.setAttribute("selected", "");
      select.appendChild(opt);
    }
    panel.appendChild(ce("div", { class: "rhl-tab-head" }, ce("label", { class: "rhl-tab-head__label" }, "Auth:"), select));

    if (kind === "bearer") {
      const b = ensureKvBlock("auth:bearer");
      panel.appendChild(formRow("Token", b, "token"));
    } else if (kind === "basic") {
      const b = ensureKvBlock("auth:basic");
      panel.appendChild(formRow("Username", b, "username"));
      panel.appendChild(formRow("Password", b, "password"));
    } else if (kind === "apikey") {
      const b = ensureKvBlock("auth:apikey");
      panel.appendChild(formRow("Key",   b, "key"));
      panel.appendChild(formRow("Value", b, "value"));
      panel.appendChild(formRow("Placement (header/queryparams)", b, "placement"));
    } else {
      panel.appendChild(ce("div", { class: "rhl-hint" }, "No auth headers added."));
    }
  }

  function formRow(label, block, field) {
    const pair = block.pairs.find(([k]) => k === field);
    const input = ce("input", {
      class: "rhl-input-wide",
      value: pair?.[1] || "",
      placeholder: field,
      oninput: (e) => {
        const p = block.pairs.find(([k]) => k === field);
        if (p) p[1] = e.target.value;
        else block.pairs.push([field, e.target.value]);
      }
    });
    return ce("div", { class: "rhl-form-row" }, ce("label", {}, label), input);
  }

  function renderRawTab(panel, blockName, placeholder) {
    const block = ensureRawBlock(blockName);
    const ta = ce("textarea", {
      class: "rhl-textarea",
      placeholder,
      spellcheck: "false",
      oninput: (e) => { block.raw = e.target.value; }
    });
    ta.value = block.raw || "";
    panel.appendChild(ta);
  }

  // Read-only variant for `script:*` and `tests` blocks: rails-http-lab
  // persists them verbatim in the .bru file but never executes them — only
  // Bruno desktop can run JS. Show the content faded so it's obvious.
  function renderReadOnlyRawTab(panel, blockName, placeholder) {
    const block = ensureRawBlock(blockName);
    panel.appendChild(ce("div", { class: "rhl-readonly-banner" },
      "Read-only — this block is preserved in the .bru file so Bruno desktop can execute it. " +
      "rails-http-lab does not run JavaScript on the Rails server."
    ));
    const ta = ce("textarea", {
      class: "rhl-textarea rhl-textarea--readonly",
      placeholder,
      spellcheck: "false",
      readonly: true
    });
    ta.value = block.raw || "";
    panel.appendChild(ta);
  }

  // ---------- Send / Save ----------
  async function sendRequest() {
    const session = activeSession();
    if (!session) { showError("No request loaded."); return; }
    syncVerbAndUrlIntoDoc();
    setResponseState("Sending…", "", "", "");

    // Read the select directly — state.envName can lag behind if the
    // browser restored a selection on reload without firing 'change'.
    const envName = $("#rhl-env-select").value || state.envName || "";
    state.envName = envName;
    try {
      const resp = await api("POST", "/run", {
        source: serializeDoc(session.doc),
        environment: envName
      });
      session.response = resp;
      session.touched = Date.now();
      showResponse(resp);
      schedulePersist();
    } catch (e) {
      session.response = { error: e.message };
      showError(e.message);
      schedulePersist();
    }
  }

  async function saveRequest() {
    const session = activeSession();
    if (!session) return;
    syncVerbAndUrlIntoDoc();
    let path = session.path || state.currentKey;
    if (!path) {
      path = window.prompt("Save as (relative path, e.g. MyAPI/login.bru)");
      if (!path) return;
      if (!path.endsWith(".bru")) path += ".bru";
    }
    try {
      await api("PUT", `/requests/${encodePath(path)}`, { source: serializeDoc(session.doc) });
      if (path !== session.path) {
        state.sessions.delete(session.path);
        session.path = path;
        state.sessions.set(path, session);
        state.currentKey = path;
      }
      session.savedDoc = cloneDoc(session.doc);  // now clean
      session._wasDirty = false;
      ensureExpanded(parentDir(path));
      await loadTree();
      updateSaveDirty();
      schedulePersist();
      flashStatus("Saved");
    } catch (e) {
      showError(e.message);
    }
  }

  function syncVerbAndUrlIntoDoc() {
    if (!currentDoc()) return;
    setVerbName($("#rhl-verb").value.toLowerCase());
    setVerbPair("url", $("#rhl-url").value);
  }

  // Fired on any edit inside the editor pane: refresh the dirty indicators and
  // schedule a localStorage write. Re-renders the sidebar only when the dirty
  // state of the active request flips (cheap; avoids reflow on every keystroke).
  function onDocEdited() {
    const s = activeSession();
    if (!s) return;
    s.touched = Date.now();
    const dirty = isDirty(s);
    updateSaveDirty(dirty);
    if (dirty !== s._wasDirty) {
      s._wasDirty = dirty;
      if (state.tree) renderTree();
    }
    schedulePersist();
  }

  function updateSaveDirty(dirty) {
    const s = activeSession();
    const d = dirty != null ? dirty : (s && isDirty(s));
    $("#rhl-save").classList.toggle("is-dirty", !!d);
  }

  // ---------- Response display ----------
  function resetResponse() {
    $("#rhl-response-status").textContent = "Ready";
    $("#rhl-response-status").className   = "";
    $("#rhl-response-time").textContent   = "";
    $("#rhl-response-size").textContent   = "";
    $("#rhl-response-body").textContent   = "Click Send to execute the request.";
    $("#rhl-response-body").className     = "rhl-response__body";
    $("#rhl-response-pretty").textContent = "";
    $("#rhl-response-pretty").className   = "rhl-response__body";
    $("#rhl-response-curl").textContent   = "";
    $("#rhl-response-curl").className     = "rhl-response__body";
    renderResponseHeaders(null);
    setResponseTab("body");
  }

  function setResponseState(status, time, size, body) {
    $("#rhl-response-status").textContent = status;
    $("#rhl-response-time").textContent   = time;
    $("#rhl-response-size").textContent   = size;
    $("#rhl-response-body").textContent   = body;
    $("#rhl-response-body").className     = "rhl-response__body";
    $("#rhl-response-pretty").textContent = body;
    $("#rhl-response-pretty").className   = "rhl-response__body";
    renderResponseHeaders(null);
  }

  function showResponse(resp) {
    if (resp.error) { showError(resp.error, resp.request); return; }
    const statusEl = $("#rhl-response-status");
    const reason   = STATUS_TEXT[resp.status] || "";
    statusEl.textContent = reason ? `${resp.status} ${reason}` : `${resp.status}`;
    statusEl.className = `rhl-pill rhl-pill--${statusFamily(resp.status)}`;
    $("#rhl-response-time").textContent = resp.duration_ms != null ? `${resp.duration_ms} ms` : "";
    $("#rhl-response-size").textContent = resp.size_bytes != null ? `${resp.size_bytes} B` : "";

    if (resp.bodyTruncated) {
      const note = "(response body too large to keep after reload — re-send to view it)";
      $("#rhl-response-body").textContent   = note;
      $("#rhl-response-body").className      = "rhl-response__body";
      $("#rhl-response-pretty").textContent  = note;
      $("#rhl-response-pretty").className     = "rhl-response__body";
    } else {
      const rawBody = resp.body || "";
      let prettyBody = rawBody;
      let isJson = false;
      try {
        prettyBody = JSON.stringify(JSON.parse(rawBody), null, 2);
        isJson = true;
      } catch (_) {}

      $("#rhl-response-body").textContent = prettyBody;
      $("#rhl-response-body").className   = "rhl-response__body";

      const pretty = $("#rhl-response-pretty");
      pretty.className = "rhl-response__body";
      if (isJson) {
        pretty.innerHTML = highlightJson(prettyBody);
      } else {
        pretty.textContent = prettyBody;
      }
    }

    renderResponseHeaders(resp.headers);

    const curl = buildCurl(resp.request);
    $("#rhl-response-curl").textContent = curl || "(no request was sent — see the error)";
    $("#rhl-response-curl").className   = "rhl-response__body";
  }

  function showError(message, request) {
    $("#rhl-response-status").textContent = "ERROR";
    $("#rhl-response-status").className = "rhl-pill rhl-pill--err";
    $("#rhl-response-time").textContent = "";
    $("#rhl-response-size").textContent = "";
    $("#rhl-response-body").textContent = message;
    $("#rhl-response-body").className   = "rhl-response__body rhl-response__body--err";
    $("#rhl-response-pretty").textContent = message;
    $("#rhl-response-pretty").className   = "rhl-response__body rhl-response__body--err";
    const curl = request ? buildCurl(request) : "";
    $("#rhl-response-curl").textContent = curl || "(no request was sent — see the error)";
    $("#rhl-response-curl").className   = "rhl-response__body";
    renderResponseHeaders(null);
    setResponseTab("body");
  }

  // Lightweight JSON syntax highlighter — escapes HTML, then wraps tokens.
  // Strings, keys, numbers, booleans, null. No external deps.
  function highlightJson(text) {
    const escaped = text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
    return escaped.replace(
      /("(?:\\u[a-fA-F0-9]{4}|\\[^u]|[^\\"])*"(?:\s*:)?)|\b(true|false)\b|\b(null)\b|(-?\d+(?:\.\d+)?(?:[eE][+\-]?\d+)?)/g,
      (m, str, bool, nul, num) => {
        if (str !== undefined) {
          const cls = /:\s*$/.test(str) ? "rhl-tok--key" : "rhl-tok--str";
          return `<span class="rhl-tok ${cls}">${str}</span>`;
        }
        if (bool) return `<span class="rhl-tok rhl-tok--bool">${bool}</span>`;
        if (nul)  return `<span class="rhl-tok rhl-tok--null">${nul}</span>`;
        if (num)  return `<span class="rhl-tok rhl-tok--num">${num}</span>`;
        return m;
      }
    );
  }

  function statusFamily(s) {
    if (s >= 500) return "err";
    if (s >= 400) return "warn";
    if (s >= 200) return "ok";
    return "info";
  }

  function renderResponseHeaders(headers) {
    const container = $("#rhl-response-headers");
    const badge     = $("#rhl-response-headers-count");
    container.innerHTML = "";

    const entries = headers && typeof headers === "object" ? Object.entries(headers) : [];
    if (entries.length === 0) {
      badge.hidden = true;
      container.appendChild(ce("div", { class: "rhl-hint" }, "No response headers."));
      return;
    }

    badge.textContent = String(entries.length);
    badge.hidden = false;

    const table = ce("table", { class: "rhl-headers-table" });
    table.appendChild(ce("thead", {}, ce("tr", {},
      ce("th", {}, "Name"), ce("th", {}, "Value"))));
    const tbody = ce("tbody");
    entries.forEach(([name, value]) => {
      const v = Array.isArray(value) ? value.join(", ") : String(value);
      tbody.appendChild(ce("tr", {},
        ce("td", { class: "rhl-headers-table__name" }, name),
        ce("td", { class: "rhl-headers-table__value" }, v)
      ));
    });
    table.appendChild(tbody);
    container.appendChild(table);
  }

  function setResponseTab(tab) {
    const s = activeSession();
    if (s) s.responseTab = tab;
    document.querySelectorAll(".rhl-response-tab").forEach((el) => {
      el.classList.toggle("is-active", el.dataset.rtab === tab);
    });
    $("#rhl-response-pretty").hidden  = tab !== "pretty";
    $("#rhl-response-body").hidden    = tab !== "body";
    $("#rhl-response-headers").hidden = tab !== "headers";
    $("#rhl-response-curl").hidden    = tab !== "curl";
  }

  // Builds the cURL equivalent of the request the runner just sent.
  function buildCurl(req) {
    if (!req || !req.url) return "";
    const parts = ["curl"];
    const method = (req.method || "GET").toUpperCase();
    if (method !== "GET") parts.push(`-X ${method}`);
    parts.push(shellQuote(req.url));
    for (const [name, value] of Object.entries(req.headers || {})) {
      parts.push(`-H ${shellQuote(`${name}: ${value}`)}`);
    }
    if (req.body && String(req.body).length > 0) {
      parts.push(`--data-raw ${shellQuote(String(req.body))}`);
    }
    return parts.join(" \\\n  ");
  }

  // POSIX single-quote escape: wrap in '…', and escape inner ' as '\''.
  function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
  }

  function flashStatus(msg) {
    const prev = $("#rhl-response-status").textContent;
    $("#rhl-response-status").textContent = msg;
    setTimeout(() => { if ($("#rhl-response-status").textContent === msg) $("#rhl-response-status").textContent = prev; }, 1200);
  }

  // ---------- Resizable splitter ----------
  function bindSplitter() {
    const splitter = $("#rhl-splitter");
    const panel    = $("#rhl-panel");
    const response = $("#rhl-response");
    let dragging = false, startY = 0, startPanelPx = 0, startResponsePx = 0;

    splitter.addEventListener("mousedown", (e) => {
      dragging = true; startY = e.clientY;
      startPanelPx    = panel.getBoundingClientRect().height;
      startResponsePx = response.getBoundingClientRect().height;
      document.body.style.cursor = "row-resize";
      e.preventDefault();
    });
    window.addEventListener("mousemove", (e) => {
      if (!dragging) return;
      const dy = e.clientY - startY;
      const newPanel    = Math.max(80, startPanelPx + dy);
      const newResponse = Math.max(80, startResponsePx - dy);
      panel.style.flex = "0 0 " + newPanel + "px";
      response.style.flex = "0 0 " + newResponse + "px";
    });
    window.addEventListener("mouseup", () => {
      if (!dragging) return;
      dragging = false;
      document.body.style.cursor = "";
    });
  }

  // ---------- Environment editor (modal) ----------
  let envState = { name: null, vars: [] };

  async function openEnvModal() {
    const modal = $("#rhl-env-modal");
    modal.hidden = false;
    await renderEnvList();
  }
  function closeEnvModal() { $("#rhl-env-modal").hidden = true; }

  async function renderEnvList() {
    const list = $("#rhl-envs-list");
    list.innerHTML = "";
    const data = await api("GET", "/environments");
    for (const env of (data.environments || [])) {
      const row = ce("div", { class: "rhl-envs-list__item" }, env.name);
      row.addEventListener("click", () => loadEnv(env.name));
      list.appendChild(row);
    }
    list.appendChild(ce("button", {
      class: "rhl-btn rhl-btn--ghost",
      onclick: async () => {
        const name = window.prompt("Environment name (e.g. Staging)");
        if (!name) return;
        await api("PUT", `/environments/${encodeURIComponent(name)}`, { vars: [] });
        await renderEnvList();
        loadEnv(name);
      }
    }, "+ New environment"));
  }

  async function loadEnv(name) {
    const data = await api("GET", `/environments/${encodeURIComponent(name)}`);
    envState.name = name;
    envState.vars = (data.vars || []).map(([k, v]) => [k, v]);
    renderEnvEditor();
  }

  function renderEnvEditor() {
    const editor = $("#rhl-envs-editor");
    editor.innerHTML = "";

    if (!envState.name) {
      editor.appendChild(ce("em", {}, "Select an environment on the left."));
      return;
    }

    editor.appendChild(ce("h3", {}, envState.name));

    const table = ce("table", { class: "rhl-kv-table" });
    table.appendChild(ce("thead", {}, ce("tr", {},
      ce("th", {}, "Name"), ce("th", {}, "Value"), ce("th", {}))));
    const tbody = ce("tbody");
    envState.vars.forEach((pair, i) => {
      const tr = ce("tr");
      tr.appendChild(ce("td", {}, ce("input", {
        value: pair[0] || "", placeholder: "name",
        oninput: (e) => { envState.vars[i][0] = e.target.value; }
      })));
      tr.appendChild(ce("td", {}, ce("input", {
        value: pair[1] || "", placeholder: "value",
        oninput: (e) => { envState.vars[i][1] = e.target.value; }
      })));
      tr.appendChild(ce("td", { class: "rhl-kv-table__del" }, ce("button", {
        class: "rhl-iconbtn",
        onclick: () => { envState.vars.splice(i, 1); renderEnvEditor(); }
      }, "×")));
      tbody.appendChild(tr);
    });
    table.appendChild(tbody);
    editor.appendChild(table);

    editor.appendChild(ce("button", {
      class: "rhl-btn rhl-btn--ghost",
      onclick: () => { envState.vars.push(["", ""]); renderEnvEditor(); }
    }, "+ Add variable"));

    editor.appendChild(ce("div", { class: "rhl-envs-editor__footer" },
      ce("button", {
        class: "rhl-btn rhl-btn--send",
        onclick: async () => {
          await api("PUT", `/environments/${encodeURIComponent(envState.name)}`, {
            vars: envState.vars.map(([k, v]) => ({ key: k, value: v }))
          });
          await loadTree();
          flashStatus("Env saved");
          $("#rhl-envs-editor h3").textContent = envState.name + " ✓";
        }
      }, "Save"),
      ce("button", {
        class: "rhl-btn",
        onclick: closeEnvModal
      }, "Close")
    ));
  }

  // ---------- Wiring ----------
  function bindActions() {
    $("#rhl-tabs").addEventListener("click", (e) => {
      const t = e.target.closest(".rhl-tab");
      if (t) setActiveTab(t.dataset.tab);
    });

    $("#rhl-response-tabs").addEventListener("click", (e) => {
      const t = e.target.closest(".rhl-response-tab");
      if (t) setResponseTab(t.dataset.rtab);
    });

    $("#rhl-send").addEventListener("click", sendRequest);
    $("#rhl-save").addEventListener("click", saveRequest);

    $("#rhl-env-select").addEventListener("change", (e) => { state.envName = e.target.value; schedulePersist(); });
    $("#rhl-env-edit").addEventListener("click", openEnvModal);
    $("#rhl-env-modal-close").addEventListener("click", closeEnvModal);
    $("#rhl-env-modal").addEventListener("click", (e) => {
      if (e.target.dataset.close === "1") closeEnvModal();
    });

    const clearBtn = $("#rhl-clear-cache");
    if (clearBtn) clearBtn.addEventListener("click", clearCache);

    $("#rhl-new-collection").addEventListener("click", promptNewCollection);

    // Any edit inside the editor pane → refresh dirty indicators + persist.
    const editor = $("#rhl-editor");
    editor.addEventListener("input", onDocEdited);
    editor.addEventListener("change", onDocEdited);

    // Keep verb/url synced into the active doc as the user types.
    $("#rhl-verb").addEventListener("change", () => { if (currentDoc()) setVerbName($("#rhl-verb").value.toLowerCase()); });
    $("#rhl-url").addEventListener("input",   () => { if (currentDoc()) setVerbPair("url", $("#rhl-url").value); });
  }

  document.addEventListener("DOMContentLoaded", async () => {
    bindActions();
    bindSplitter();
    hydrateSessions();
    try {
      await loadTree();
      pruneSessions();
      restoreLastSession();
    } catch (e) {
      $("#rhl-tree").textContent = "Error: " + e.message;
    }
  });
})();
