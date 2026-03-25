/**
 * Altair Yedressov — Portfolio Frontend (Node.js / Express)
 * Fetches data from the Python FastAPI backend and renders a single-page portfolio.
 */

const express = require("express");
const axios = require("axios");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;
const API_URL = process.env.API_URL || "http://localhost:8000";

app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "../views"));
app.use(express.static(path.join(__dirname, "../public")));

// ── Main route ──────────────────────────────────────────────────────────────
app.get("/", async (req, res) => {
  try {
    const { data } = await axios.get(`${API_URL}/api/all`);
    res.render("index", { data });
  } catch (err) {
    console.error("Backend API unreachable:", err.message);
    res.status(503).render("error", {
      message: "Backend API is unreachable. Ensure the Python service is running.",
    });
  }
});

// ── Health check ────────────────────────────────────────────────────────────
app.get("/health", async (req, res) => {
  try {
    const backend = await axios.get(`${API_URL}/api/health`);
    res.json({
      status: "healthy",
      service: "portfolio-frontend",
      backend: backend.data,
    });
  } catch {
    res.status(503).json({
      status: "degraded",
      service: "portfolio-frontend",
      backend: "unreachable",
    });
  }
});

app.listen(PORT, () => {
  console.log(`✦  Frontend running → http://localhost:${PORT}`);
  console.log(`✦  Backend API      → ${API_URL}`);
});
