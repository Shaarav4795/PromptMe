"use client";

import { useEffect } from "react";

function initAosLikeReveal(): () => void {
  const body = document.body;
  const previousDuration = body.getAttribute("data-aos-duration");
  const previousEasing = body.getAttribute("data-aos-easing");

  body.setAttribute("data-aos-duration", "700");
  body.setAttribute("data-aos-easing", "ease-out-cubic");

  const animated = Array.from(
    document.querySelectorAll<HTMLElement>("[data-aos]")
  );

  animated.forEach((node) => {
    node.classList.add("aos-init");
  });

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("aos-animate");
          observer.unobserve(entry.target);
        }
      }
    },
    {
      threshold: 0.1,
      rootMargin: "0px 0px -10% 0px",
    }
  );

  animated.forEach((node) => observer.observe(node));

  return () => {
    observer.disconnect();

    if (previousDuration === null) {
      body.removeAttribute("data-aos-duration");
    } else {
      body.setAttribute("data-aos-duration", previousDuration);
    }

    if (previousEasing === null) {
      body.removeAttribute("data-aos-easing");
    } else {
      body.setAttribute("data-aos-easing", previousEasing);
    }
  };
}

export function PromptMeInteractions() {
  useEffect(() => {
    const teardownAos = initAosLikeReveal();

    return () => {
      teardownAos();
    };
  }, []);

  return null;
}
