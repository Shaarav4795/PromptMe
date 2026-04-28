import type { ReactElement } from "react";
import Image from "next/image";
import { CheckIcon } from "./icons";

export function PricingGridSection(): ReactElement {
  return (
    <section id="pricing">
      <div className="l-stage">
        <div className="pm-surface-overlay pm-surface-overlay--stacked pm-surface-overlay--top-right-border" aria-hidden="true"></div>
        <div className="pm-surface-overlay pm-surface-overlay--stacked pm-surface-overlay--top-right-fade" aria-hidden="true"></div>

        <div className="l-shell">
          <div className="pm-section-padding">
            <div className="l-section-copy">
              <div className="pm-section-intro" data-aos="fade-up">
                <h2 className="pm-section-title">Choose your PromptMe plan</h2>
                <p className="c-lead-copy-muted">
                  Start free while beta is active, then move to advanced modes as your production workflow grows.
                </p>
              </div>

              <div className="pm-pricing-grid" data-aos="fade-up" data-aos-delay="100">
                <div className="c-plan-card">
                  <div className="pm-card-block-spaced">
                    <div className="c-plan-heading">Beta</div>
                    <Image className="c-plan-image" src="/promptme/images/features-02.png" width={210} height={124} alt="PromptMe beta plan" />
                  </div>
                  <div className="pm-card-cta-block">
                    <div className="c-plan-price">Free</div>
                    <a className="c-cta-btn-primary pm-btn-full" href="#download">
                      Download beta
                    </a>
                  </div>
                  <div className="c-plan-feature-label">Features include</div>
                  <ul className="c-plan-feature-list">
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Notch overlay controls</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Script import and export</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Pause, resume, and jump back</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Countdown start</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Local-only settings storage</span>
                    </li>
                  </ul>
                </div>

                <div className="c-plan-card c-plan-card--featured">
                  <div className="c-plan-badge">Popular</div>
                  <div className="pm-card-block-spaced">
                    <div className="c-plan-heading">Creator</div>
                    <Image className="c-plan-image" src="/promptme/images/features-03.png" width={210} height={124} alt="PromptMe creator plan" />
                  </div>
                  <div className="pm-card-cta-block">
                    <div className="c-plan-price">$8/mo</div>
                    <a className="c-cta-btn-dark pm-btn-full" href="mailto:hello@promptme.app?subject=PromptMe%20Creator%20Waitlist">
                      Join waitlist
                    </a>
                  </div>
                  <div className="c-plan-feature-label">Everything in Beta, plus</div>
                  <ul className="c-plan-feature-list">
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Voice-assisted pacing (Phase 2)</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Mic sensitivity controls</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Advanced smoothing modes</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Priority feature voting</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Early access builds</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Direct support channel</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Usage diagnostics dashboard</span>
                    </li>
                  </ul>
                </div>

                <div className="c-plan-card">
                  <div className="pm-card-block-spaced">
                    <div className="c-plan-heading">Studio</div>
                    <Image className="c-plan-image" src="/promptme/images/features-04.png" width={210} height={124} alt="PromptMe studio plan" />
                  </div>
                  <div className="pm-card-cta-block">
                    <div className="c-plan-price">$16/mo</div>
                    <a className="c-cta-btn-primary pm-btn-full" href="mailto:hello@promptme.app?subject=PromptMe%20Studio%20Waitlist">
                      Join waitlist
                    </a>
                  </div>
                  <div className="c-plan-feature-label">Everything in Creator, plus</div>
                  <ul className="c-plan-feature-list">
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Multi-script library</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Cue markers and sections</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Keyboard shortcut profiles</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Session templates</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Team-shared style presets</span>
                    </li>
                  </ul>
                </div>

                <div className="c-plan-card">
                  <div className="pm-card-block-spaced">
                    <div className="c-plan-heading">Team</div>
                    <Image className="c-plan-image" src="/promptme/images/hero-image.png" width={210} height={124} alt="PromptMe team plan" />
                  </div>
                  <div className="pm-card-cta-block">
                    <div className="c-plan-price">$29/mo</div>
                    <a className="c-cta-btn-primary pm-btn-full" href="mailto:hello@promptme.app?subject=PromptMe%20Team%20Plan">
                      Contact us
                    </a>
                  </div>
                  <div className="c-plan-feature-label">Everything in Studio, plus</div>
                  <ul className="c-plan-feature-list">
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Shared script workspaces</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Roles and approvals</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Centralized policy settings</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Team onboarding templates</span>
                    </li>
                    <li className="c-list-row-start">
                      <CheckIcon />
                      <span>Priority SLA support</span>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
