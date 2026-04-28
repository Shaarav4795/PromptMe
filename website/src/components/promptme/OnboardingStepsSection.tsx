import type { ReactElement } from "react";
import Image from "next/image";

export function OnboardingStepsSection(): ReactElement {
  return (
    <section id="setup">
      <div className="l-stage">
        <div className="pm-surface-overlay pm-surface-overlay--top-right-blue" aria-hidden="true"></div>

        <div className="l-shell">
          <div className="pm-section-padding">
            <div className="l-section-copy">
              <div className="pm-section-intro" data-aos="fade-up">
                <h2 className="pm-section-title-on-dark">Set up PromptMe in under five minutes</h2>
                <p className="c-lead-copy-blue">
                  Install, paste your script, choose a target display, and start reading with confidence. No account or
                  cloud sync required.
                </p>
              </div>

              <div className="pm-onboarding-preview" data-aos="fade-up" data-aos-delay="100">
                <div className="pm-onboarding-preview-frame">
                  <Image src="/promptme/images/features-02.png" width={775} height={618} alt="PromptMe setup flow screenshot" />
                </div>
              </div>

              <div className="pm-three-column-grid pm-three-column-grid--left" data-aos="fade-up" data-aos-delay="200">
                <div className="c-step-connector c-step-connector--blue">
                  <div className="pm-capability-icon">
                    <div className="c-step-badge">1</div>
                  </div>
                  <h4 className="pm-feature-title-on-dark">Install and launch from menu bar</h4>
                  <p className="pm-feature-copy-on-dark">
                    PromptMe runs as a focused menu bar utility and keeps the Dock hidden so your desktop remains clean.
                  </p>
                </div>

                <div className="c-step-connector c-step-connector--blue">
                  <div className="pm-capability-icon">
                    <div className="c-step-badge">2</div>
                  </div>
                  <h4 className="pm-feature-title-on-dark">Import or write your script</h4>
                  <p className="pm-feature-copy-on-dark">
                    Bring in common document formats or write directly in settings to prep your speaking notes quickly.
                  </p>
                </div>

                <div className="c-step-connector c-step-connector--blue">
                  <div className="pm-capability-icon">
                    <div className="c-step-badge">3</div>
                  </div>
                  <h4 className="pm-feature-title-on-dark">Pick display and begin scrolling</h4>
                  <p className="pm-feature-copy-on-dark">
                    Choose the active monitor, set pace, and optionally start with countdown so delivery feels natural.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
