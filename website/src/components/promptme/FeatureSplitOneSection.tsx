import type { ReactElement } from "react";
import Image from "next/image";
import { ArrowIcon } from "./icons";

export function FeatureSplitOneSection(): ReactElement {
  return (
    <section data-aos-id-2>
      <div className="l-stage">
        <div className="pm-surface-overlay pm-surface-overlay--stacked pm-surface-overlay--top-right-dark" aria-hidden="true"></div>

        <div className="l-shell">
          <div className="pm-section-padding-compact">
            <div className="l-section-copy">
              <div className="pm-section-copy-width-sm">
                <h2 className="pm-section-title-on-dark" data-aos="fade-up" data-aos-anchor="[data-aos-id-2]" data-aos-delay="100">
                  Write once, present anywhere on your setup
                </h2>
                <p className="c-lead-copy-on-dark" data-aos="fade-up" data-aos-anchor="[data-aos-id-2]" data-aos-delay="200">
                  PromptMe keeps your script in a dedicated settings editor while the live overlay follows your chosen
                  display. It is built for meetings, tutorials, and live demos.
                </p>
                <div className="pm-cta-narrow" data-aos="fade-up" data-aos-anchor="[data-aos-id-2]" data-aos-delay="300">
                  <div>
                    <a className="c-cta-btn-primary pm-cta-with-arrow" href="#setup">
                      See setup flow
                      <span className="pm-cta-arrow pm-cta-arrow--sky">
                        <ArrowIcon />
                      </span>
                    </a>
                  </div>
                </div>
                <div className="l-quote-row" data-aos="fade-up" data-aos-anchor="[data-aos-id-2]" data-aos-delay="300">
                  <Image className="c-quote-avatar" src="/promptme/images/quote-author-02.jpg" width={32} height={32} alt="PromptMe beta user" />
                  <div>
                    <blockquote className="pm-quote-copy-on-dark">
                      PromptMe replaced my sticky notes and frantic tab switching. I can keep eye contact and still hit
                      every key point.
                    </blockquote>
                  </div>
                </div>
              </div>
              <div className="l-two-col-media-right">
                <div className="l-two-col-media-inner" data-aos="fade-up" data-aos-anchor="[data-aos-id-2]">
                  <Image src="/promptme/images/features-02.png" className="pm-media-image-expand" width={775} height={618} alt="PromptMe script editor and overlay" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
