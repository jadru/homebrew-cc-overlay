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
    <div className="meter" aria-label={`${label} capacity preview`}>
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
    <section className="status-rail" aria-label="Live usage preview">
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
        <strong>61%</strong>
      </div>
      <Meter label="Network" segments={["on", "on", "on", "off", "off", "off", "off", "off", "off"]} />
      <Meter label="Codex · 72% left" segments={["on", "on", "on", "on", "on", "on", "off", "off", "off"]} />
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
            <p className="eyebrow">SYSTEM + AI CAPACITY / CC-OVRLY-01</p>
            <h1>Know your room<br />before the run.</h1>
            <div className="hero-action-block">
              <p>One compact view for your Mac's live capacity<br />and Codex or Claude Code headroom.</p>
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
            <span>CURRENT / RELEASES</span>
          </div>

          <div className="hero-status">
            <StatusRail />
            <div className="status-meta" aria-label="Connection details">
              <span>STATUS: CONNECTED</span>
              <span>SOURCE: ANTHROPIC + OPENAI</span>
              <span>UPDATED: JUST NOW</span>
            </div>
          </div>
        </section>

        <section className="product-proof shell" aria-labelledby="product-proof-title">
          <div className="product-proof__copy">
          <span className="section-kicker">01 / ONE CAPACITY SURFACE</span>
          <h2 id="product-proof-title">System health,<br />AI headroom.</h2>
          <p>The compact overlay stays useful with no provider connected. Expand it for a 60-minute system view, accessible top processes, and rate-limit detail when Codex or Claude Code is available.</p>
          </div>
          <figure className="product-shot system-preview">
            <div className="system-preview__window" aria-label="Example expanded system capacity overlay">
              <div className="system-preview__header">
                <span>System capacity</span>
                <span>Thermal · Normal</span>
              </div>
              <div className="system-preview__metrics">
                <span><small>CPU</small><strong>42%</strong><em>overall load</em></span>
                <span><small>Memory</small><strong>61%</strong><em>swap 1.2 GB</em></span>
                <span><small>Network</small><strong>↓ 1.8 MB/s</strong><em>↑ 240 KB/s</em></span>
                <span><small>Storage</small><strong>184 GB</strong><em>free space</em></span>
              </div>
              <div className="system-preview__usage">
                <span>Codex</span><b>72% left</b><i aria-hidden="true" />
                <span>Claude Code</span><b>48% left</b><i className="system-preview__usage--warning" aria-hidden="true" />
              </div>
            </div>
            <figcaption>EXPANDED SYSTEM MONITOR / LOCAL-FIRST</figcaption>
          </figure>
        </section>

        <section className="story shell" aria-labelledby="story-title">
          <div className="section-title-block">
          <span className="section-kicker">02 / PURPOSE</span>
          <h2 id="story-title">One glance.<br />Better calls.</h2>
          </div>
          <div className="story-copy">
            <article>
              <h3>Mac capacity first.</h3>
              <p>CPU, memory pressure, network, storage, power, and thermal state explain whether the machine is ready for the next demanding task.</p>
            </article>
            <article>
              <h3>Always nearby.</h3>
              <p>A native macOS overlay stays compact above your work, opens focused details on demand, and can be limited to developer tools.</p>
            </article>
            <article>
              <h3>AI capacity in context.</h3>
              <p>Codex and Claude Code headroom, reset timing, and pace live beside system conditions instead of in a separate dashboard.</p>
            </article>
          </div>
          <CrosshairSimple className="story-mark" weight="thin" aria-hidden="true" />
        </section>

        <section className="install shell" aria-labelledby="install-title">
          <div className="install__header">
            <span className="section-kicker">03 / INSTALL</span>
            <h2 id="install-title">One command.<br />Then stay in flow.</h2>
          </div>
          <div className="install__body">
            <InstallCommand location="install-section" />
            <ol className="install-steps">
              <li><span>01</span><p>Install the signed universal macOS app with Homebrew.</p></li>
              <li><span>02</span><p>Launch <code>cc-overlay</code>. Detected providers appear automatically.</p></li>
              <li><span>03</span><p>Enable Claude OAuth only if you want live Claude rate-limit windows.</p></li>
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
            <a href={repositoryUrl} target="_blank" rel="noreferrer" onClick={() => recordIntent("Source opened", "trust") }>
              View source <ArrowRight aria-hidden="true" />
            </a>
          </article>

          <article className="proof-item">
            <LockKey weight="light" aria-hidden="true" />
            <h2>Local-first</h2>
            <span className="proof-rule" aria-hidden="true" />
            <p>No developer backend. Your credentials and usage history stay on your Mac.</p>
            <a href={`${repositoryUrl}#privacy-and-provider-access`} target="_blank" rel="noreferrer" onClick={() => recordIntent("Privacy opened", "trust") }>
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
