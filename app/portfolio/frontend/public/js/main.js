/* ═══════════════════════════════════════════════════════════════
   PORTFOLIO — Main JavaScript
   ═══════════════════════════════════════════════════════════════ */

/* ── Sound state (module scope) ──────────────────────────────── */
let soundEnabled = false;
let audioUnlocked = false;
let keyAudio = null;     // pool of HTMLAudioElements, lazily created
let keyAudioIdx = 0;     // round-robin index into the pool
let lastPlay = 0;        // throttle timestamp (performance.now)
const KEY_THROTTLE_MS = 25;

document.addEventListener("DOMContentLoaded", () => {
  initTheme();
  initSound();
  initNav();
  initReveal();
  initCountUp();
  initTerminal();
  initSkillsTerminal();
  initExpTerminals();
  initContactForm();
  setFooterYear();
});

/* ── Sound Toggle ─────────────────────────────────────────────── */
function initSound() {
  const toggle = document.getElementById("soundToggle");
  if (!toggle) return;

  const saved = localStorage.getItem("sound-enabled");
  if (saved === "true") {
    soundEnabled = true;
    document.documentElement.setAttribute("data-sound", "on");
  }
  toggle.setAttribute("aria-pressed", String(soundEnabled));

  toggle.addEventListener("click", async () => {
    soundEnabled = !soundEnabled;
    localStorage.setItem("sound-enabled", String(soundEnabled));
    document.documentElement.setAttribute("data-sound", soundEnabled ? "on" : "off");
    toggle.setAttribute("aria-pressed", String(soundEnabled));

    // First time we enable sound, use this click as the user gesture to unlock audio.
    if (soundEnabled && !audioUnlocked) {
      try {
        keyAudio = Array.from({ length: 4 }, () => {
          const a = new Audio("/audio/keypress.mp3");
          a.volume = 0.35;
          a.preload = "auto";
          return a;
        });
        const primer = keyAudio[0];
        await primer.play();
        primer.pause();
        primer.currentTime = 0;
        audioUnlocked = true;
      } catch (_) {
        // NotAllowedError or asset missing — silently leave audio locked.
      }
    }
  });
}

/* ── Throttled key-press emitter ──────────────────────────────── */
function playKey() {
  if (!soundEnabled || !audioUnlocked || !keyAudio) return;
  const now = performance.now();
  if (now - lastPlay < KEY_THROTTLE_MS) return;
  lastPlay = now;
  const a = keyAudio[keyAudioIdx];
  keyAudioIdx = (keyAudioIdx + 1) % keyAudio.length;
  try { a.currentTime = 0; } catch (_) { /* ignore */ }
  a.play().catch(() => { /* swallow autoplay rejections */ });
}

/* ── Theme Toggle ─────────────────────────────────────────────── */
function initTheme() {
  const toggle = document.getElementById("themeToggle");
  if (!toggle) return;

  // Check saved preference — default is light (set in HTML)
  const saved = localStorage.getItem("theme");
  if (saved === "dark") {
    document.documentElement.removeAttribute("data-theme");
  }

  toggle.addEventListener("click", () => {
    const current = document.documentElement.getAttribute("data-theme");
    if (current === "light") {
      document.documentElement.removeAttribute("data-theme");
      localStorage.setItem("theme", "dark");
    } else {
      document.documentElement.setAttribute("data-theme", "light");
      localStorage.setItem("theme", "light");
    }
  });
}

/* ── Navigation ──────────────────────────────────────────────── */
function initNav() {
  const nav = document.getElementById("nav");
  const burger = document.getElementById("burger");
  const mobileMenu = document.getElementById("mobileMenu");

  // Scroll shadow
  const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 40);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Burger toggle
  burger.addEventListener("click", () => {
    burger.classList.toggle("active");
    mobileMenu.classList.toggle("open");
    document.body.style.overflow = mobileMenu.classList.contains("open") ? "hidden" : "";
  });

  // Close on link click
  mobileMenu.querySelectorAll("a").forEach((link) =>
    link.addEventListener("click", () => {
      burger.classList.remove("active");
      mobileMenu.classList.remove("open");
      document.body.style.overflow = "";
    })
  );
}

/* ── Scroll Reveal ───────────────────────────────────────────── */
function initReveal() {
  const els = document.querySelectorAll(".reveal");
  if (!els.length) return;

  const observer = new IntersectionObserver(
    (entries) =>
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add("visible");
          observer.unobserve(e.target);
        }
      }),
    { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
  );

  els.forEach((el) => observer.observe(el));
}

/* ── Count-up Animation ──────────────────────────────────────── */
function initCountUp() {
  const nums = document.querySelectorAll("[data-count]");
  if (!nums.length) return;

  const observer = new IntersectionObserver(
    (entries) =>
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        const el = e.target;
        const target = parseInt(el.dataset.count, 10);
        animateCount(el, target);
        observer.unobserve(el);
      }),
    { threshold: 0.5 }
  );

  nums.forEach((n) => observer.observe(n));
}

function animateCount(el, target) {
  const duration = 1600;
  const start = performance.now();

  function tick(now) {
    const progress = Math.min((now - start) / duration, 1);
    const eased = 1 - Math.pow(1 - progress, 4); // easeOutQuart
    el.textContent = Math.round(eased * target);
    if (progress < 1) requestAnimationFrame(tick);
  }

  requestAnimationFrame(tick);
}

/* ── Terminal Typing Effect — 5 lines + clear command ─────────── */
function initTerminal() {
  const textEl = document.getElementById("terminalText");
  const historyEl = document.getElementById("terminalHistory");
  const promptEl = document.querySelector(".terminal__active-line .terminal__prompt");
  if (!textEl || !historyEl) return;

  const bulletSets = [
    [
      "Managing 15+ EKS clusters & 20+ microservices",
      "Built self-service CI/CD for 30+ engineers",
      "Cut releases from days → hours",
      "Reduced infra costs 40% with Karpenter",
      "Deployed Istio mesh + Thanos metrics",
    ],
    [
      "Zero unplanned downtime via Rancher",
      "Containerized 8 legacy services → EKS",
      "Saved ~$50K/year in EC2 costs",
      "Built EFK logging for 15+ services",
      "Automated CI/CD with GitHub Actions",
    ],
    [
      "Multi-region failover on AWS",
      "Passed security review — 0 critical findings",
      "Teleport zero-trust access across K8s",
      "FluxCD bootstrap in EKS Terraform module",
      "Kyverno policy + Trivy vuln scanning",
    ],
  ];

  let setIdx = 0;

  function typeText(text, speed, cb) {
    let i = 0;
    function tick() {
      i++;
      textEl.textContent = text.slice(0, i);
      if (i < text.length) {
        setTimeout(tick, speed + Math.random() * (speed * 0.6));
      } else {
        cb();
      }
    }
    tick();
  }

  function commitLine(text, isCommand) {
    const div = document.createElement("div");
    div.className = "terminal__history-line";
    const prompt = document.createElement("span");
    prompt.className = "terminal__prompt";
    prompt.textContent = isCommand ? "$" : "▹";
    const content = document.createElement("span");
    content.textContent = text;
    if (isCommand) content.style.color = "var(--text-muted)";
    div.appendChild(prompt);
    div.appendChild(content);
    historyEl.appendChild(div);
  }

  function typeBullets(lines, idx, cb) {
    if (idx >= lines.length) { cb(); return; }

    typeText(lines[idx], 45, () => {
      setTimeout(() => {
        commitLine(lines[idx], false);
        textEl.textContent = "";
        setTimeout(() => typeBullets(lines, idx + 1, cb), 300);
      }, 120);
    });
  }

  function runClearSequence(cb) {
    // Pause so user can read
    setTimeout(() => {
      // Switch prompt to $ for command
      promptEl.textContent = "$";
      
      // Type "clear"
      typeText("clear", 70, () => {
        setTimeout(() => {
          // Commit the clear command to history briefly
          commitLine("clear", true);
          textEl.textContent = "";

          // Simulate clear: scroll everything up rapidly then wipe
          setTimeout(() => {
            historyEl.style.transition = "transform 0.25s ease-in, opacity 0.25s ease-in";
            historyEl.style.transform = "translateY(-100%)";
            historyEl.style.opacity = "0";

            setTimeout(() => {
              historyEl.innerHTML = "";
              historyEl.style.transition = "none";
              historyEl.style.transform = "";
              historyEl.style.opacity = "";
              // Reset prompt back to ▹
              promptEl.textContent = "▹";
              cb();
            }, 300);
          }, 150);
        }, 400);
      });
    }, 2200);
  }

  function runSet() {
    const lines = bulletSets[setIdx % bulletSets.length];

    typeBullets(lines, 0, () => {
      runClearSequence(() => {
        setIdx++;
        setTimeout(runSet, 500);
      });
    });
  }

  setTimeout(runSet, 1200);
}

/* ── Skills Terminal + Visualization Animation ───────────────── */
function initSkillsTerminal() {
  const output = document.getElementById("skillsTermOutput");
  const typingEl = document.getElementById("skillsTyping");
  const cursorEl = document.getElementById("skillsCursor");
  const vizEmpty = document.getElementById("vizEmpty");
  if (!output || !typingEl) return;

  const categories = [
    {
      cmd: "terraform apply cloud_infrastructure.tf",
      status: "Apply complete! 12 resources added.",
      vizId: "vizCloud",
      tagsId: "vizCloudTags",
      tags: ["AWS", "Azure", "GCP", "Terraform", "Helm", "Kubernetes", "Docker", "Linux", "Karpenter", "Rancher", "Istio", "Velero"],
    },
    {
      cmd: "flux bootstrap cicd_gitops.yaml",
      status: "Reconciliation complete. 5 sources synced.",
      vizId: "vizCicd",
      tagsId: "vizCicdTags",
      tags: ["GitHub Actions", "FluxCD", "ArgoCD", "Jenkins", "GitLab CI"],
    },
    {
      cmd: "kubectl apply -f observability-stack.yaml",
      status: "8 monitoring components deployed.",
      vizId: "vizObs",
      tagsId: "vizObsTags",
      tags: ["Prometheus", "Grafana", "Alertmanager", "OpenTelemetry", "EFK Stack", "CloudWatch", "Datadog", "Thanos"],
    },
    {
      cmd: "vault operator init --security-policies",
      status: "Vault initialized. 8 policies applied.",
      vizId: "vizSec",
      tagsId: "vizSecTags",
      tags: ["Teleport", "HashiCorp Vault", "IAM", "VPC Security", "mTLS", "Kyverno", "SealedSecrets", "Audit Logging"],
    },
    {
      cmd: "kafka-topics --create data_messaging",
      status: "7 data streams provisioned.",
      vizId: "vizData",
      tagsId: "vizDataTags",
      tags: ["Apache Kafka", "Amazon Kinesis", "PgBouncer", "RDS", "Aurora", "DocumentDB", "DynamoDB"],
    },
    {
      cmd: "claude --init ai_dev_tools",
      status: "AI toolkit ready. 7 tools loaded.",
      vizId: "vizAi",
      tagsId: "vizAiTags",
      tags: ["Claude", "Claude Code", "GitHub Copilot", "Cursor", "MCP", "AI Agents", "Prompt Engineering"],
    },
  ];

  let started = false;
  const observer = new IntersectionObserver(
    (entries) => {
      if (entries[0].isIntersecting && !started) {
        started = true;
        observer.unobserve(entries[0].target);
        runSkillsSequence();
      }
    },
    { threshold: 0.2 }
  );
  observer.observe(document.getElementById("skillsSection"));

  function typeCmd(text, cb) {
    let i = 0;
    function tick() {
      i++;
      const ch = text[i - 1];
      if (ch && ch.trim()) playKey();
      typingEl.textContent = text.slice(0, i);
      if (i < text.length) setTimeout(tick, 35 + Math.random() * 20);
      else cb();
    }
    tick();
  }

  function commitCmd(text) {
    const line = document.createElement("div");
    line.className = "exp-terminal__cmd-line";
    line.innerHTML =
      '<span class="exp-terminal__ps1">$</span>' +
      '<span class="exp-terminal__cmd">' + esc(text) + "</span>";
    output.appendChild(line);
    typingEl.textContent = "";
  }

  function addStatus(text) {
    const line = document.createElement("div");
    line.className = "skills__term-status";
    line.textContent = "✓ " + text;
    output.appendChild(line);
  }

  function showCategory(cat, cb) {
    const vizEl = document.getElementById(cat.vizId);
    const tagsEl = document.getElementById(cat.tagsId);

    // Remove hidden, add active + deploying glow
    vizEl.hidden = false;
    vizEl.classList.add("active", "deploying");

    // Pop in tags one by one
    let i = 0;
    function popNext() {
      if (i >= cat.tags.length) {
        // Remove deploying glow after all tags
        setTimeout(() => vizEl.classList.remove("deploying"), 300);
        cb();
        return;
      }
      const tag = document.createElement("span");
      tag.className = "skills__viz-tag";
      tag.textContent = cat.tags[i];
      tagsEl.appendChild(tag);
      // Trigger pop animation
      requestAnimationFrame(() => {
        requestAnimationFrame(() => tag.classList.add("pop"));
      });
      i++;
      setTimeout(popNext, 60);
    }
    popNext();
  }

  function esc(s) {
    const el = document.createElement("span");
    el.textContent = s;
    return el.innerHTML;
  }

  function runCategory(idx, cb) {
    if (idx >= categories.length) { cb(); return; }
    const cat = categories[idx];

    typeCmd(cat.cmd, () => {
      setTimeout(() => {
        commitCmd(cat.cmd);

        // Hide empty message on first command
        if (idx === 0 && vizEmpty) vizEmpty.hidden = true;

        setTimeout(() => {
          showCategory(cat, () => {
            addStatus(cat.status);
            setTimeout(() => runCategory(idx + 1, cb), 400);
          });
        }, 200);
      }, 150);
    });
  }

  function runSkillsSequence() {
    // Initial mkdir command
    typeCmd("mkdir skills-and-tools && cd skills-and-tools", () => {
      setTimeout(() => {
        commitCmd("mkdir skills-and-tools && cd skills-and-tools");

        setTimeout(() => {
          runCategory(0, () => {
            // All deployed — type clear
            setTimeout(() => {
              typeCmd("clear", () => {
                setTimeout(() => {
                  commitCmd("clear");
                  setTimeout(() => {
                    output.style.transition = "transform 0.25s ease-in, opacity 0.25s ease-in";
                    output.style.transform = "translateY(-100%)";
                    output.style.opacity = "0";
                    setTimeout(() => {
                      output.innerHTML = "";
                      output.style.transition = "none";
                      output.style.transform = "";
                      output.style.opacity = "";
                      cursorEl.style.display = "none";
                    }, 300);
                  }, 150);
                }, 300);
              });
            }, 1500);
          });
        }, 400);
      }, 150);
    });
  }
}

/* ── Experience Terminal Animation ────────────────────────────── */
function initExpTerminals() {
  const body = document.getElementById("expBody");
  const output = document.getElementById("expOutput");
  const typingEl = document.getElementById("expTyping");
  const cursorEl = document.getElementById("expCursor");
  const titleEl = document.getElementById("expTitle");
  if (!body || !output) return;

  const TYPE_SPEED = 40;
  let started = false;

  const observer = new IntersectionObserver(
    (entries) => {
      if (entries[0].isIntersecting && !started) {
        started = true;
        observer.unobserve(body);
        runFullSequence();
      }
    },
    { threshold: 0.2 }
  );
  observer.observe(body);

  function typeCmd(text, cb) {
    let i = 0;
    function tick() {
      i++;
      const ch = text[i - 1];
      if (ch && ch.trim()) playKey();
      typingEl.textContent = text.slice(0, i);
      if (i < text.length) setTimeout(tick, TYPE_SPEED + Math.random() * (TYPE_SPEED * 0.5));
      else cb();
    }
    tick();
  }

  function commitCmd(text) {
    const line = document.createElement("div");
    line.className = "exp-terminal__cmd-line";
    line.innerHTML =
      '<span class="exp-terminal__ps1">$</span>' +
      '<span class="exp-terminal__cmd">' + esc(text) + "</span>";
    output.appendChild(line);
    typingEl.textContent = "";
  }

  function addHeader(role, company, dates) {
    const h = document.createElement("div");
    h.className = "exp-terminal__role-header";
    h.innerHTML =
      '<span class="exp-terminal__company-name">' + esc(company) + "</span> — " +
      esc(role) +
      '  <span class="exp-terminal__dates">' + esc(dates) + "</span>";
    output.appendChild(h);

    const sep = document.createElement("div");
    sep.className = "exp-terminal__separator";
    sep.textContent = "─".repeat(48);
    output.appendChild(sep);
  }

  function addBullet(text, cb) {
    const line = document.createElement("div");
    line.className = "exp-terminal__bullet";
    line.innerHTML = '<span class="exp-terminal__arrow">▹</span>' + esc(text);
    output.appendChild(line);
    setTimeout(cb, 120);
  }

  function addBullets(bullets, idx, cb) {
    if (idx >= bullets.length) { cb(); return; }
    addBullet(bullets[idx], () => addBullets(bullets, idx + 1, cb));
  }

  function addBlankLine() {
    const br = document.createElement("div");
    br.style.height = "12px";
    output.appendChild(br);
  }

  function esc(s) {
    const el = document.createElement("span");
    el.textContent = s;
    return el.innerHTML;
  }

  function runCompany(cmd, titlePath, role, company, dates, bullets, cb) {
    typeCmd(cmd, () => {
      setTimeout(() => {
        commitCmd(cmd);
        titleEl.textContent = "altair@infra ~/" + titlePath;

        setTimeout(() => {
          typeCmd("cat achievements.log", () => {
            setTimeout(() => {
              commitCmd("cat achievements.log");

              setTimeout(() => {
                addHeader(role, company, dates);

                setTimeout(() => {
                  addBullets(bullets, 0, cb);
                }, 200);
              }, 300);
            }, 200);
          });
        }, 400);
      }, 200);
    });
  }

  function runFullSequence() {
    // Figma
    runCompany(
      "cd ~/experience/figma",
      "experience/figma",
      "Infrastructure / Platform Engineer",
      "Figma",
      "Feb 2022 – Present",
      [
        "Managing 15+ EKS clusters and 20+ microservices",
        "Built self-service CI/CD for 30+ engineers, cutting releases from days to hours",
        "Reduced infrastructure costs 40% with Karpenter autoscaling",
        "Deployed Istio service mesh (mTLS, gateway) and Thanos for long-term metrics",
        "Deployed Teleport for zero-trust access; cut onboarding from days to minutes",
        "Managing clusters via Rancher with zero unplanned downtime",
        "Automated IAM provisioning with Terraform permission-boundary policies",
        "Built FluxCD bootstrap into EKS Terraform module",
        "Provisioned RDS/Aurora/DocumentDB with cross-region backups, sub-30min RTO",
        "Implemented Kyverno policy enforcement and Trivy vuln scanning",
        "Reduced pipeline execution time by 40%",
      ],
      () => {
        // Blank line between companies
        addBlankLine();

        setTimeout(() => {
          // FanDuel
          runCompany(
            "cd ../fanduel",
            "experience/fanduel",
            "Junior DevOps Engineer",
            "FanDuel",
            "Mar 2020 – Jan 2022",
            [
              "Containerized 8 legacy services and migrated to EKS, saving ~$50K/year",
              "Built EFK logging stack for 15+ microservices",
              "Implemented Sealed Secrets for GitOps-native secret management",
              "Created reusable Terraform modules for IAM provisioning",
              "Automated CI/CD with GitHub Actions for 4 teams",
              "Hardened networking (VPC, security groups, mTLS) — 0 critical findings",
              "Architected multi-region failover on AWS",
            ],
            () => {
              // Done — hide cursor
              cursorEl.style.display = "none";
            }
          );
        }, 600);
      }
    );
  }
}

/* ── Contact Form ────────────────────────────────────────────── */
function initContactForm() {
  const form = document.getElementById("contactForm");
  if (!form) return;

  form.addEventListener("submit", async (e) => {
    e.preventDefault();

    const btnText = document.querySelector(".btn__text");
    const btnLoader = document.querySelector(".btn__loader");
    const feedback = document.getElementById("formFeedback");
    const submitBtn = document.getElementById("submitBtn");

    // Gather values
    const name = form.name.value.trim();
    const email = form.email.value.trim();
    const subject = form.subject.value.trim();
    const message = form.message.value.trim();

    // Client-side validation
    clearErrors(form);
    const errors = [];
    if (name.length < 2) errors.push({ field: "name", msg: "Name is required." });
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))
      errors.push({ field: "email", msg: "Valid email is required." });
    if (subject.length < 3) errors.push({ field: "subject", msg: "Subject is required." });
    if (message.length < 10)
      errors.push({ field: "message", msg: "Message must be at least 10 characters." });

    if (errors.length) {
      errors.forEach(({ field }) => form[field].classList.add("error"));
      showFeedback(feedback, errors[0].msg, "error");
      return;
    }

    // Submit
    btnText.hidden = true;
    btnLoader.hidden = false;
    submitBtn.disabled = true;

    try {
      const res = await fetch("/api/contact", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, email, subject, message }),
      });

      const data = await res.json();

      if (res.ok && data.success) {
        showFeedback(feedback, data.message || "Message sent successfully!", "success");
        form.reset();
      } else {
        const errMsg =
          data.errors?.join(" ") || data.error || "Something went wrong. Please try again.";
        showFeedback(feedback, errMsg, "error");
      }
    } catch {
      showFeedback(feedback, "Network error. Please check your connection and try again.", "error");
    } finally {
      btnText.hidden = false;
      btnLoader.hidden = true;
      submitBtn.disabled = false;
    }
  });
}

function clearErrors(form) {
  form.querySelectorAll(".error").forEach((el) => el.classList.remove("error"));
  const fb = document.getElementById("formFeedback");
  fb.hidden = true;
  fb.className = "form-feedback";
}

function showFeedback(el, msg, type) {
  el.textContent = msg;
  el.className = `form-feedback ${type}`;
  el.hidden = false;

  if (type === "success") {
    setTimeout(() => {
      el.hidden = true;
    }, 6000);
  }
}

/* ── Footer Year ─────────────────────────────────────────────── */
function setFooterYear() {
  const el = document.getElementById("year");
  if (el) el.textContent = new Date().getFullYear();
}
