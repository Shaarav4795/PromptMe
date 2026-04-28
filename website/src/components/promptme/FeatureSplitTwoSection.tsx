import type { ReactElement } from "react";
import Image from "next/image";
import { ArrowIcon } from "./icons";

export function FeatureSplitTwoSection(): ReactElement {
  return (
    <section className="pm-section-gap-lg" data-aos-id-3>
      <div className="l-stage">
        <div className="pm-surface-overlay pm-surface-overlay--stacked pm-surface-overlay--top-left-fade" aria-hidden="true"></div>

        <div className="l-shell">
          <div className="pm-section-padding-bottom">
            <div className="l-two-col-layout-end">
              <div className="pm-two-col-copy-pane pm-two-col-copy-pane--order-last-md">
                <h2 className="pm-section-title" data-aos="fade-up" data-aos-anchor="[data-aos-id-3]" data-aos-delay="100">
                  Built for real presentation pressure
                </h2>
                <p className="c-lead-copy-muted" data-aos="fade-up" data-aos-anchor="[data-aos-id-3]" data-aos-delay="200">
                  Use countdown starts, jump-back controls, privacy-safe sharing, and multi-display targeting so your
                  prompt behaves predictably during live calls.
                </p>
                <div className="pm-cta-narrow" data-aos="fade-up" data-aos-anchor="[data-aos-id-3]" data-aos-delay="300">
                  <div>
                    <a className="c-cta-btn-primary pm-cta-with-arrow" href="https://github.com/shaarav4795/promptme">
                      Download now
                      <span className="pm-cta-arrow pm-cta-arrow--sky">
                        <ArrowIcon />
                      </span>
                    </a>
                  </div>
                </div>
                <div className="l-quote-row" data-aos="fade-up" data-aos-anchor="[data-aos-id-3]" data-aos-delay="300">
                  <Image className="c-quote-avatar" src="/promptme/images/quote-author-02.jpg" width={32} height={32} alt="PromptMe creator" />
                  <div>
                    <blockquote className="pm-quote-copy">
                      Hover-to-pause is the killer detail. When questions interrupt me, I stop naturally and continue
                      exactly where I left off.
                    </blockquote>
                  </div>
                </div>
              </div>
              <div className="l-two-col-media-right">
                <div className="l-two-col-media-inner">
                  <Image
                    src="/promptme/images/features-03.png"
                    className="pm-media-image-expand"
                    width={496}
                    height={395}
                    alt="PromptMe controls and pace settings"
                    data-aos="fade-up"
                    data-aos-anchor="[data-aos-id-3]"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
