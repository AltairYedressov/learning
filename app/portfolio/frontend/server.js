/**
 * Portfolio Frontend Server
 * Serves static assets and proxies /api/* requests to the Python backend.
 */

require("dotenv").config();
const express = require("express");
const compression = require("compression");
const helmet = require("helmet");
const path = require("path");
const { createProxyMiddleware } = require("http-proxy-middleware");

const app = express();

const PORT = process.env.PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || "http://localhost:5000";

// ── Security & Performance ──────────────────────────────────────────────────
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
        fontSrc: ["'self'", "https://fonts.gstatic.com"],
        imgSrc: ["'self'", "data:", "https:"],
        connectSrc: ["'self'", BACKEND_URL],
      },
    },
  })
);
app.use(compression());

// ── Local Health Probe ─────────────────────────────────────────────────────
// Liveness/readiness probe — intentionally does NOT proxy to the backend.
// Frontend liveness must be independent of backend reachability (CONTEXT D-02).
app.get("/health", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

// ── API Proxy ───────────────────────────────────────────────────────────────
app.use(
  "/api",
  createProxyMiddleware({
    target: BACKEND_URL,
    changeOrigin: true,
    timeout: 10000,
    onError: (err, req, res) => {
      console.error(`[Proxy Error] ${err.message}`);
      res.status(502).json({ success: false, error: "Backend service unavailable." });
    },
  })
);

// ── Static Assets ───────────────────────────────────────────────────────────
app.use(
  express.static(path.join(__dirname, "public"), {
    maxAge: process.env.NODE_ENV === "production" ? "7d" : 0,
    etag: true,
  })
);

// ── SPA Fallback ────────────────────────────────────────────────────────────
app.get("*", (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// ── Start ───────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n  ✦  Frontend  → http://localhost:${PORT}`);
  console.log(`  ✦  Backend   → ${BACKEND_URL}`);
  console.log(`  ✦  Env       → ${process.env.NODE_ENV || "development"}\n`);
});
