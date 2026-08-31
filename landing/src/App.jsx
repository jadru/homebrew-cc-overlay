import { useState } from "react";
import { track } from "@vercel/analytics";
import {
  AppleLogo,
  ArrowDown,
  ArrowRight,
  Check,
  Code,
  Copy,
  CrosshairSimple,
  GithubLogo,
  LockKey,
  Moon,
  Sun,
} from "@phosphor-icons/react";

const repositoryUrl = "https://github.com/jadru/homebrew-cc-overlay";
const releaseUrl = `${repositoryUrl}/releases/latest`;
const installCommand = "brew tap jadru/cc-overlay && brew install cc-overlay";

const layouts = [
  {
    title: "Horizontal",
    detail: "A familiar one-line rail for CPU, memory, network, storage, AI, and Dashboard.",
    image: "/images/overlay-horizontal.png",
    alt: "CC-Overlay horizontal layout showing CPU, RAM, network, SSD, Codex, and Dashboard",
  },
  {
    title: "Vertical",
    detail: "A calm stack that gives every reading room to breathe.",
    image: "/images/overlay-vertical.png",
    alt: "CC-Overlay vertical layout showing system and Codex readings",
  },
  {
    title: "Two columns",
    detail: "A compact grid for dense workspaces and smaller displays.",
    image: "/images/overlay-two-column.png",
    alt: "CC-Overlay two-column layout showing system and Codex readings",
  },
];

function recordIntent(name, location) {
  track(name, { location });
}

function InstallCommand({ location = "page" }) {
  const [copied, setCopied] = useState(false);

  async function copyInstallCommand() {
    try {
      await navigator.clipboard.writeText(installCommand);
    } catch {
      const fallback = document.createElement("textarea");
      fallback.value = installCommand;
      fallback.setAttribute("readonly", "");
      fallback.style.position = "fixed";
      fallback.style.opacity = "0";
      document.body.appendChild(fallback);
      fallback.select();
      document.execCommand("copy");
      fallback.remove();
    }
    setCopied(true);
    recordIntent("Install command copied", location);
    window.setTimeout(() => setCopied(false), 1800);
  }

  return (
    <div className="install-command">
      <code>{installCommand}</code>
      <button type="button" onClick={copyInstallCommand} aria-label="Copy Homebrew install command">
        {copied ? <Check weight="bold" aria-hidden="true" /> : <Copy weight="regular" aria-hidden="true" />}
        <span>{copied ? "Copied" : "Copy"}</span>
      </button>
    </div>
  );
}

function Meter({ label, segments }) {
  return (
    <div className="meter" aria-label={`${label} sample reading`}>
      <span className="meter__label">{label}</span>
      <span className="meter__track" aria-hidden="true">
        {segments.map((tone, index) => (
          <span className={`meter__segment meter__segment--${tone}`} key={`${label}-${index}`} />
        ))}
      </span>
    </div>
  );
}

function StatusRail() {
  return (
    <section className="status-rail" aria-label="Example local capacity readings">
      <div className="window-dots" aria-hidden="true">
        <span className="window-dot window-dot--red" />
        <span className="window-dot window-dot--yellow" />
        <span className="window-dot window-dot--green" />
      </div>
      <div className="status-reading">
        <strong>42%</strong>
        <span>CPU</span>
      </div>
      <div className="status-reset">
        <span>Memory</span>
        <strong>61% used</strong>
      </div>
      <Meter label="Network · 1.8 MB/s" segments={["on", "on", "on", "off", "off", "off", "off", "off", "off"]} />
      <Meter label="Codex · 72% left" segments={["on", "on", "on", "on", "on", "on", "off", "off", "off"]} />
    </section>
  );
}

function MiniHeadroomChart() {
  return (
    <svg className="headroom-chart" viewBox="0 0 320 72" role="img" aria-label="Seven-day Codex and Claude Code headroom trend">
      <title>Seven-day AI headroom trend</title>
      <path className="headroom-chart__grid" d="M0 12H320M0 36H320M0 60H320" />
      <path className="headroom-chart__codex" d="M0 53 L45 45 L91 50 L137 32 L183 39 L229 20 L274 29 L320 12" />
      <path className="headroom-chart__claude" d="M0 59 L45 57 L91 43 L137 49 L183 34 L229 40 L274 25 L320 31" />
      <circle className="headroom-chart__point" cx="320" cy="12" r="3" />
      <circle className="headroom-chart__point headroom-chart__point--claude" cx="320" cy="31" r="3" />
    </svg>
  );
}

function HeroDecision() {
  return (
    <div className="hero-decision" aria-label="Example capacity decision">
      <img
        className="hero-decision__overlay"
        src="/images/overlay-horizontal.png"
        alt="CC-Overlay horizontal system capacity overlay"
      />
      <section className="decision-card">
        <div className="decision-card__topline">
          <span>Next action</span>
          <span>Safe now</span>
        </div>
        <strong>Run with caution</strong>
        <p>Memory pressure is elevated. Close heavy apps, or start the next task with care.</p>
        <div className="decision-card__meta">
          <span>Recommended: Codex</span>
          <span>High confidence</span>
        </div>
        <div className="decision-card__chart">
          <div className="chart-label"><span>7-day headroom</span><span>now</span></div>
          <MiniHeadroomChart />
          <div className="chart-legend" aria-label="Chart legend"><span><i className="chart-legend__codex" />Codex</span><span><i className="chart-legend__claude" />Claude Code</span></div>
        </div>
      </section>
    </div>
  );
}

function LayoutGallery() {
  return (
    <section className="layout-gallery shell" id="layouts" aria-labelledby="layouts-title">
      <div className="layout-gallery__heading">
        <span className="section-kicker">01 / PRESENTATION</span>
        <h2 id="layouts-title">Three shapes.<br />Same signal.</h2>
        <p>Switch layouts from the overlay’s right-click menu or Settings. Your preferred shape stays put after relaunch.</p>
      </div>
      <div className="layout-gallery__items">
        {layouts.map((layout, index) => (
          <figure className={`layout-card layout-card--${index + 1}`} key={layout.title}>
            <div className="layout-card__image-wrap">
              <img src={layout.image} alt={layout.alt} />
            </div>
            <figcaption>
              <span>0{index + 1}</span>
              <div><strong>{layout.title}</strong><p>{layout.detail}</p></div>
            </figcaption>
          </figure>
        ))}
      </div>
    </section>
  );
}

function DecisionFlow() {
  const steps = [
    ["Wait for Mac", "Critical memory pressure or thermal state wins."],
    ["Refresh or set up", "Connect a provider or refresh stale readings."],
    ["Wait, switch, or reset", "Use the earliest usable provider window."],
    ["Run with caution", "Proceed with clear Mac-level constraints."],
    ["Run now", "Start when the machine and a provider are ready."],
  ];

  return (
    <section className="decision-flow shell" aria-labelledby="decision-flow-title">
      <div className="decision-flow__heading">
        <span className="section-kicker">02 / DECISION ORDER</span>
        <h2 id="decision-flow-title">Make the call<br />before the run.</h2>
      </div>
      <ol className="decision-flow__steps">
        {steps.map(([title, detail], index) => (
          <li key={title}>
            <span className="decision-flow__index">0{index + 1}</span>
            <h3>{title}</h3>
            <p>{detail}</p>
          </li>
        ))}
      </ol>
      <CrosshairSimple className="decision-flow__mark" weight="thin" aria-hidden="true" />
    </section>
  );
}

export function App() {
  const [isDark, setIsDark] = useState(false);

  return (
    <div className={isDark ? "site site--dark" : "site"}>
      <a className="skip-link" href="#main">Skip to content</a>

      <header className="site-header shell">
        <a className="wordmark" href="#top" aria-label="CC-Overlay home">CC-Overlay</a>
        <nav className="site-nav" aria-label="Primary navigation">
          <a href={repositoryUrl} target="_blank" rel="noreferrer">View source</a>
          <a href="#requirements">macOS 15+</a>
          <button
            className="theme-toggle"
            type="button"
            onClick={() => setIsDark((current) => !current)}
            aria-label={`Switch to ${isDark ? "light" : "dark"} mode`}
          >
            {isDark ? <Moon weight="light" /> : <Sun weight="light" />}
          </button>
        </nav>
      </header>

      <main id="main">
        <section className="hero shell" id="top">
          <CrosshairSimple className="hero-mark hero-mark--left" weight="thin" aria-hidden="true" />
          <CrosshairSimple className="hero-mark hero-mark--right" weight="thin" aria-hidden="true" />

          <div className="hero-copy">
            <h1>Know your room<br />before the run.</h1>
            <div className="hero-action-block">
              <p>Mac readiness, AI headroom, and the next safe action<br />in one compact local view.</p>
              <a
                className="primary-button"
                href={releaseUrl}
                target="_blank"
                rel="noreferrer"
                onClick={() => recordIntent("Release opened", "hero")}
              >
                <ArrowDown weight="regular" aria-hidden="true" />
                View latest release
              </a>
              <span className="button-note">Signed &amp; notarized · macOS 15+</span>
              <InstallCommand location="hero" />
            </div>
          </div>

          <div className="hero-side-note" aria-hidden="true">
            <span>CC-OVERLAY</span>
            <span>//</span>
            <span>LOCAL CAPACITY</span>
            <span>MAC + PROVIDERS</span>
          </div>

          <HeroDecision />

          <div className="hero-status">
            <StatusRail />
            <div className="status-meta" aria-label="Example reading details">
              <span>LOCAL READINGS / SAMPLE STATE</span>
              <span>MAC + PROVIDER / DECISION READY</span>
              <span>PRIVATE BY DEFAULT</span>
            </div>
          </div>
        </section>

        <LayoutGallery />
        <DecisionFlow />

        <section className="local-insight shell" aria-labelledby="local-insight-title">
          <div className="local-insight__title">
            <span className="section-kicker">03 / PROJECT INSIGHT</span>
            <h2 id="local-insight-title">Local insight.<br />Honest language.</h2>
          </div>
          <div className="local-insight__copy">
            <article>
              <h3>Projects, without the payload.</h3>
              <p>See the active 24-hour projects, provider badges, session counts, and token totals. CC-Overlay shows only the final directory name, never raw paths or conversation content.</p>
            </article>
            <article>
              <h3>Cost language that stays true.</h3>
              <p>Codex is labeled as local tokens and contribution to its limit, not a bill. Claude’s dollar hint is explicitly a local API-equivalent estimate.</p>
            </article>
          </div>
          <CrosshairSimple className="local-insight__mark" weight="thin" aria-hidden="true" />
        </section>

        <section className="install shell" aria-labelledby="install-title">
          <div className="install__header">
            <span className="section-kicker">04 / INSTALL</span>
            <h2 id="install-title">One command.<br />Then stay in flow.</h2>
          </div>
          <div className="install__body">
            <InstallCommand location="install-section" />
            <ol className="install-steps">
              <li><span>01</span><p>Install the signed universal macOS app with Homebrew.</p></li>
              <li><span>02</span><p>Launch <code>cc-overlay</code>. Detected providers appear automatically.</p></li>
              <li><span>03</span><p>Use the overlay, Dashboard, or AI popover to choose the next move.</p></li>
            </ol>
            <a
              className="text-link"
              href={`${repositoryUrl}#install`}
              target="_blank"
              rel="noreferrer"
              onClick={() => recordIntent("Install docs opened", "install-section")}
            >
              Read install and verification notes <ArrowRight aria-hidden="true" />
            </a>
          </div>
        </section>

        <section className="proof shell" id="requirements" aria-label="Product trust">
          <div className="maker-note">
            <CrosshairSimple weight="thin" aria-hidden="true" />
            <span>CC-OVERLAY<br />BUILT FOR DEVELOPERS</span>
          </div>

          <article className="proof-item">
            <Code weight="light" aria-hidden="true" />
            <h2>Open source</h2>
            <span className="proof-rule" aria-hidden="true" />
            <p>Transparent by default. Source available for audit, extension, and trust.</p>
            <a href={repositoryUrl} target="_blank" rel="noreferrer" onClick={() => recordIntent("Source opened", "trust")}>
              View source <ArrowRight aria-hidden="true" />
            </a>
          </article>

          <article className="proof-item">
            <LockKey weight="light" aria-hidden="true" />
            <h2>Local-first</h2>
            <span className="proof-rule" aria-hidden="true" />
            <p>No developer backend. Your credentials and usage history stay on your Mac.</p>
            <a href={`${repositoryUrl}#privacy-and-provider-access`} target="_blank" rel="noreferrer" onClick={() => recordIntent("Privacy opened", "trust")}>
              Learn more <ArrowRight aria-hidden="true" />
            </a>
          </article>
        </section>
      </main>

      <footer className="site-footer shell">
        <span>© 2026 CC-Overlay</span>
        <div className="footer-links">
          <span><AppleLogo weight="fill" aria-hidden="true" /> Made for macOS</span>
          <a href={repositoryUrl} target="_blank" rel="noreferrer" aria-label="CC-Overlay on GitHub">
            <GithubLogo weight="fill" aria-hidden="true" />
          </a>
        </div>
      </footer>
    </div>
  );
}
