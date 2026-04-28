import type { ReactElement } from "react";
import Image from "next/image";

export function CapabilityCardsSection(): ReactElement {
  return (
    <section>
      <div className="l-shell">
        <div className="pm-section-padding-caps">
          <div className="pm-three-column-grid">
            <div className="c-step-connector c-step-connector--slate" data-aos="fade-up">
              <div className="pm-capability-icon">
                <Image
                  className="pm-capability-icon-image"
                  src="/promptme/images/icons/capability-overlay-controls.svg"
                  width={56}
                  height={56}
                  alt=""
                  aria-hidden="true"
                />
              </div>
              <h4 className="pm-feature-title">Notch-first overlay controls</h4>
              <p className="pm-feature-copy">
                Keep your script anchored at the top with pause, rewind, countdown, and speed controls that stay out of the way.
              </p>
            </div>
            <div
              className="c-step-connector c-step-connector--slate"
              data-aos="fade-up"
              data-aos-delay="100"
            >
              <div className="pm-capability-icon">
                <Image
                  className="pm-capability-icon-image"
                  src="/promptme/images/icons/capability-scroll-pacing.svg"
                  width={56}
                  height={56}
                  alt=""
                  aria-hidden="true"
                />
              </div>
              <h4 className="pm-feature-title">Smooth auto-scroll pacing</h4>
              <p className="pm-feature-copy">
                Run continuous scroll, stop at end, or loop forever. Hover-to-pause lets you pause naturally without losing your place.
              </p>
            </div>
            <div
              className="c-step-connector c-step-connector--slate"
              data-aos="fade-up"
              data-aos-delay="200"
            >
              <div className="pm-capability-icon">
                <Image
                  className="pm-capability-icon-image"
                  src="/promptme/images/icons/capability-script-import.svg"
                  width={56}
                  height={56}
                  alt=""
                  aria-hidden="true"
                />
              </div>
              <h4 className="pm-feature-title">Import and edit scripts fast</h4>
              <p className="pm-feature-copy">
                Import txt, md, rtf, docx, odt, and pdf files, then tune your script in settings before every live session.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
