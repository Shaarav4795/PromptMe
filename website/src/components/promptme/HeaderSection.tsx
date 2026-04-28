import type { ReactElement } from "react";
import Image from "next/image";
import Link from "next/link";
import { ArrowIcon } from "./icons";

export function HeaderSection(): ReactElement {
  return (
    <header className="pm-header">
      <div className="l-shell">
        <div className="pm-header-bar">
          <div className="pm-header-brand">
            <Link className="pm-header-brand-link" href="/" aria-label="PromptMe">
              <Image src="/promptme-app-icon.png" width={30} height={30} alt="PromptMe icon" />
            </Link>
          </div>
          <nav className="pm-header-nav">
            <ul className="pm-header-nav-list">
              <li className="pm-header-nav-item">
                <a className="c-cta-btn-dark pm-cta-with-arrow" href="https://github.com/shaarav4795/promptme">
                  Download now
                  <span className="pm-cta-arrow pm-cta-arrow--cyan">
                    <ArrowIcon />
                  </span>
                </a>
              </li>
            </ul>
          </nav>
        </div>
      </div>
    </header>
  );
}
