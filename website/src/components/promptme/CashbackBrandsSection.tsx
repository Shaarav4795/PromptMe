import type { ReactElement } from "react";
import Image from "next/image";
import { ArrowIcon, ListCheckIcon } from "./icons";

export function CashbackBrandsSection(): ReactElement {
  return (
    <section className="pm-section-gap-top" data-aos-id-4>
      <div className="l-stage">
        <div className="pm-surface-overlay pm-surface-overlay--stacked pm-surface-overlay--top-right-border" aria-hidden="true"></div>
        <div className="pm-surface-overlay pm-surface-overlay--stacked pm-surface-overlay--top-right-fade" aria-hidden="true"></div>

        <div className="l-shell">
          <div className="pm-section-padding">
            <div className="l-two-col-layout">
              <div className="pm-two-col-copy-pane">
                <h2 className="pm-section-title" data-aos="fade-up" data-aos-anchor="[data-aos-id-4]" data-aos-delay="100">
                  Fits the workflows creators and teams actually use
                </h2>
                <p className="c-lead-copy-muted" data-aos="fade-up" data-aos-anchor="[data-aos-id-4]" data-aos-delay="200">
                  From solo recordings to enterprise demos, PromptMe is built to work with your tools and your speaking
                  style.
                </p>
                <div className="pm-compat-columns" data-aos="fade-up" data-aos-anchor="[data-aos-id-4]" data-aos-delay="300">
                  <div>
                    <h5 className="pm-subheading">Best for</h5>
                    <ul className="pm-checklist">
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Product demos</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Webinar hosting</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Tutorial videos</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Investor updates</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Sales walkthroughs</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Interview prep</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Team standups</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Live coding sessions</span>
                      </li>
                    </ul>
                  </div>
                  <div>
                    <h5 className="pm-subheading">Works alongside</h5>
                    <ul className="pm-checklist">
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Zoom</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Google Meet</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Microsoft Teams</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>OBS Studio</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>ScreenFlow</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Loom</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>Keynote</span>
                      </li>
                      <li className="c-list-row-center">
                        <ListCheckIcon />
                        <span>PowerPoint</span>
                      </li>
                    </ul>
                  </div>
                </div>
                <div className="pm-cta-narrow" data-aos="fade-up" data-aos-anchor="[data-aos-id-4]" data-aos-delay="300">
                  <div>
                    <a className="c-cta-btn-primary pm-cta-with-arrow" href="https://github.com/shaarav4795/promptme">
                      Download now
                      <span className="pm-cta-arrow pm-cta-arrow--sky">
                        <ArrowIcon />
                      </span>
                    </a>
                  </div>
                </div>
              </div>
              <div className="l-two-col-media-left">
                <div className="l-two-col-media-inner">
                  <Image
                    src="/promptme/images/features-04.png"
                    className="pm-media-image-expand"
                    width={496}
                    height={395}
                    alt="PromptMe compatibility overview"
                    data-aos="fade-up"
                    data-aos-anchor="[data-aos-id-4]"
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
