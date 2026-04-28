import type { ReactElement } from "react";
import Image from "next/image";
import { ArrowIcon } from "./icons";

export function HeroSection(): ReactElement {
  return (
    <section className="pm-hero">
      <div className="pm-surface-overlay pm-surface-overlay--hero" aria-hidden="true"></div>

      <div className="l-shell">
        <div className="pm-hero-inner">
          <div className="l-section-copy">
            <div className="pm-hero-copy-width">
              <h1 className="pm-hero-title" data-aos="fade-up" data-aos-delay="100">
                Stay on script during every call, demo, and{" "}
                <span className="pm-hero-highlight">
                  <Image
                    className="pm-hero-highlight-swoosh"
                    src="/promptme/images/icons/hero-recordings-underline.svg"
                    width={246}
                    height={76}
                    alt=""
                    aria-hidden="true"
                  />
                  recordings
                </span>
              </h1>
              <p className="c-lead-copy-blue" data-aos="fade-up" data-aos-delay="200">
                PromptMe is a notch-first macOS teleprompter with smooth auto-scroll,
                <br className="hidden pm-show-md-break" /> hover pause, and fast script import for confident speaking.
              </p>
              <div
                className="pm-hero-actions"
                data-aos="fade-up"
                data-aos-delay="300"
              >
                <div>
                  <a className="c-cta-btn-dark pm-btn-full pm-cta-with-arrow" href="#download">
                    Get PromptMe
                    <span className="pm-cta-arrow pm-cta-arrow--cyan">
                      <ArrowIcon />
                    </span>
                  </a>
                </div>
                <div>
                  <a className="c-cta-btn-accent pm-btn-full" href="#setup">
                    See setup flow
                  </a>
                </div>
              </div>
            </div>
            <div className="pm-hero-media-wrap">
              <div className="pm-hero-media-stage">
                <Image
                  className="pm-hero-media-glow"
                  src="/promptme/images/hero-illustration.svg"
                  width={960}
                  height={960}
                  alt=""
                  aria-hidden="true"
                />
                <Image
                  src="/promptme/images/hero-image.png"
                  className="pm-hero-media-shot"
                  width={548}
                  height={247}
                  alt="PromptMe overlay screenshot"
                  data-aos="fade-up"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
