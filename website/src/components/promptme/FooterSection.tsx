import type { ReactElement } from "react";
import Image from "next/image";
import Link from "next/link";

export function FooterSection(): ReactElement {
  return (
    <footer className="pm-footer">
      <div className="pm-footer-backdrop" aria-hidden="true"></div>

      <div className="l-shell">
        <div className="pm-footer-grid">
          <div className="pm-footer-brand-column">
            <Link className="pm-footer-brand-link" href="/" aria-label="PromptMe">
              <Image className="pm-footer-logo" src="/promptme/images/icons/logo-mark.svg" width={30} height={30} alt="PromptMe logo mark" />
            </Link>
          </div>

          <div className="pm-footer-column">
            <h6 className="c-footer-title">Product</h6>
            <ul className="c-footer-list">
              <li>
                <a className="c-footer-link" href="#setup">
                  Setup flow
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#reliability">
                  Reliability
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#pricing">
                  Pricing
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#faq">
                  FAQ
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#download">
                  Download
                </a>
              </li>
            </ul>
          </div>

          <div className="pm-footer-column">
            <h6 className="c-footer-title">Roadmap</h6>
            <ul className="c-footer-list">
              <li>
                <a className="c-footer-link" href="#0">
                  Phase 1: Core workflow
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#0">
                  Phase 2: Voice sync
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#0">
                  Phase 3: Reliability and performance
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#0">
                  Phase 4: Release readiness
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#0">
                  Open beta updates
                </a>
              </li>
            </ul>
          </div>

          <div className="pm-footer-column">
            <h6 className="c-footer-title">Resources</h6>
            <ul className="c-footer-list">
              <li>
                <a className="c-footer-link" href="#setup">
                  Script formats
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#reliability">
                  Multi-display support
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#reliability">
                  Privacy mode
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#reliability">
                  Performance goals
                </a>
              </li>
            </ul>
          </div>

          <div className="pm-footer-column">
            <h6 className="c-footer-title">Connect</h6>
            <ul className="c-footer-list">
              <li>
                <a className="c-footer-link" href="mailto:hello@promptme.app">
                  Send us an email
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#0">
                  GitHub
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#0">
                  YouTube
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#0">
                  LinkedIn
                </a>
              </li>
              <li>
                <a className="c-footer-link" href="#0">
                  X / Twitter
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="pm-footer-meta-wrap">
          <div className="pm-footer-meta">
            PromptMe is currently in active beta for macOS. Feature availability and pricing are roadmap targets and may
            change before public release. We prioritize local-first script handling and transparent performance
            improvements in each release. For support, contact{" "}
            <a className="pm-footer-meta-link" href="mailto:hello@promptme.app">
              hello@promptme.app
            </a>{" "}
            anytime.
          </div>
        </div>
      </div>
    </footer>
  );
}
