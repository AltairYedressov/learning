"""
Portfolio Backend API — Contact Form Email Service
Receives contact form submissions and sends them via SMTP.
"""

import os
import re
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from collections import defaultdict

from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = int(os.getenv("MAX_BODY_BYTES", 16384))
CORS(app, origins=os.getenv("ALLOWED_ORIGINS", "http://localhost:3000").split(","))

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", 587))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
RECIPIENT_EMAIL = os.getenv("RECIPIENT_EMAIL", "contact@yedressov.com")

# ---------------------------------------------------------------------------
# Simple in-memory rate limiter  (IP → list of timestamps)
# ---------------------------------------------------------------------------
_rate_store: dict[str, list[datetime]] = defaultdict(list)
RATE_LIMIT = int(os.getenv("RATE_LIMIT", 5))          # max messages
RATE_WINDOW = int(os.getenv("RATE_WINDOW_MINUTES", 15))  # per N minutes


def _is_rate_limited(ip: str) -> bool:
    now = datetime.utcnow()
    cutoff = now - timedelta(minutes=RATE_WINDOW)
    _rate_store[ip] = [t for t in _rate_store[ip] if t > cutoff]
    if len(_rate_store[ip]) >= RATE_LIMIT:
        return True
    _rate_store[ip].append(now)
    return False


# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------
EMAIL_RE = re.compile(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")


def _validate_payload(data: dict) -> list[str]:
    errors = []
    name = (data.get("name") or "").strip()
    email = (data.get("email") or "").strip()
    subject = (data.get("subject") or "").strip()
    message = (data.get("message") or "").strip()

    if not name or len(name) < 2:
        errors.append("Name must be at least 2 characters.")
    if not email or not EMAIL_RE.match(email):
        errors.append("A valid email address is required.")
    if not subject or len(subject) < 3:
        errors.append("Subject must be at least 3 characters.")
    if not message or len(message) < 10:
        errors.append("Message must be at least 10 characters.")
    if len(message) > 5000:
        errors.append("Message must be under 5 000 characters.")

    return errors


# ---------------------------------------------------------------------------
# Email builder
# ---------------------------------------------------------------------------
def _send_email(name: str, email: str, subject: str, message: str) -> None:
    msg = MIMEMultipart("alternative")
    msg["From"] = SMTP_USER
    msg["To"] = RECIPIENT_EMAIL
    msg["Subject"] = f"Portfolio Contact: {subject}"
    msg["Reply-To"] = email

    plain = (
        f"New message from your portfolio contact form\n"
        f"{'─' * 48}\n\n"
        f"From:    {name}\n"
        f"Email:   {email}\n"
        f"Subject: {subject}\n\n"
        f"Message:\n{message}\n"
    )

    html = f"""\
    <html>
    <body style="font-family:sans-serif;background:#0d0d0d;color:#e0e0e0;padding:32px;">
      <div style="max-width:560px;margin:auto;background:#161616;border-radius:12px;
                  border:1px solid #262626;padding:32px;">
        <h2 style="margin:0 0 24px;color:#00e5a0;">New Contact Form Message</h2>
        <table style="width:100%;border-collapse:collapse;margin-bottom:20px;">
          <tr><td style="padding:8px 12px;color:#888;width:80px;">From</td>
              <td style="padding:8px 12px;color:#fff;">{name}</td></tr>
          <tr><td style="padding:8px 12px;color:#888;">Email</td>
              <td style="padding:8px 12px;"><a href="mailto:{email}" style="color:#00e5a0;">{email}</a></td></tr>
          <tr><td style="padding:8px 12px;color:#888;">Subject</td>
              <td style="padding:8px 12px;color:#fff;">{subject}</td></tr>
        </table>
        <div style="background:#0d0d0d;border-radius:8px;padding:20px;color:#ccc;
                    line-height:1.7;white-space:pre-wrap;">{message}</div>
        <p style="margin-top:24px;font-size:12px;color:#555;">
          Sent from yedressov.com contact form
        </p>
      </div>
    </body>
    </html>
    """

    msg.attach(MIMEText(plain, "plain"))
    msg.attach(MIMEText(html, "html"))

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(SMTP_USER, SMTP_PASS)
        server.sendmail(SMTP_USER, RECIPIENT_EMAIL, msg.as_string())


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.route("/health", methods=["GET"])
def health_bare():
    return jsonify({"status": "ok"}), 200


@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "timestamp": datetime.utcnow().isoformat()})


@app.errorhandler(413)
def payload_too_large(_err):
    return jsonify({"success": False, "error": "Payload too large."}), 413


@app.before_request
def _enforce_body_cap():
    # Enforce body-size cap BEFORE route handlers run, so rate-limit and
    # SMTP are never touched by oversized requests (SEC-07 ordering).
    max_bytes = app.config.get("MAX_CONTENT_LENGTH")
    if max_bytes is not None and request.content_length is not None \
            and request.content_length > max_bytes:
        return jsonify({"success": False, "error": "Payload too large."}), 413


@app.route("/api/contact", methods=["POST"])
def contact():
    # Rate limiting
    client_ip = request.headers.get("X-Forwarded-For", request.remote_addr)
    if _is_rate_limited(client_ip):
        return jsonify({"success": False, "error": "Too many requests. Please try again later."}), 429

    data = request.get_json(silent=True) or {}
    errors = _validate_payload(data)
    if errors:
        return jsonify({"success": False, "errors": errors}), 400

    name = data["name"].strip()
    email = data["email"].strip()
    subject = data["subject"].strip()
    message = data["message"].strip()

    # If SMTP is not configured, log and return success (dev mode)
    if not SMTP_USER or not SMTP_PASS:
        logger.warning("SMTP not configured — logging message instead of sending.")
        logger.info(f"[CONTACT] From: {name} <{email}> | Subject: {subject} | Message: {message[:120]}…")
        return jsonify({"success": True, "message": "Message received (dev mode — email not sent)."})

    try:
        _send_email(name, email, subject, message)
        logger.info(f"[CONTACT] Email sent — from {email}, subject: {subject}")
        return jsonify({"success": True, "message": "Message sent successfully!"})
    except Exception as exc:
        logger.error(f"[CONTACT] Failed to send email: {exc}")
        return jsonify({"success": False, "error": "Failed to send message. Please try again later."}), 500


# ---------------------------------------------------------------------------
if __name__ == "__main__":
    port = int(os.getenv("BACKEND_PORT", 5000))
    debug = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    app.run(host="0.0.0.0", port=port, debug=debug)
