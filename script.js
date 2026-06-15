(() => {
  const TRACKING_QUERY_PARAMS = [
    "ref",
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_term",
    "utm_content",
    "gclid",
    "fbclid",
    "mc_cid",
    "mc_eid",
  ];

  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const normalizeCanonicalUrl = () => {
    const current = new URL(window.location.href);
    const isWebProtocol = current.protocol === "http:" || current.protocol === "https:";

    if (!isWebProtocol) return;

    const isProductionHost =
      current.hostname === "pillr.management" || current.hostname === "www.pillr.management";
    let changed = false;

    if (isProductionHost && current.protocol !== "https:") {
      current.protocol = "https:";
      changed = true;
    }

    if (current.hostname === "www.pillr.management") {
      current.hostname = "pillr.management";
      changed = true;
    }

    if (current.pathname === "/index.html") {
      current.pathname = "/";
      changed = true;
    }

    TRACKING_QUERY_PARAMS.forEach((param) => {
      if (current.searchParams.has(param)) {
        current.searchParams.delete(param);
        changed = true;
      }
    });

    if (!changed) return;

    const destination = `${current.origin}${current.pathname}${current.search}${current.hash}`;
    const shouldReplacePage =
      current.protocol !== window.location.protocol ||
      current.host !== window.location.host ||
      current.pathname !== window.location.pathname;

    if (shouldReplacePage) {
      window.location.replace(destination);
      return;
    }

    window.history.replaceState({}, "", destination);
  };

  const setupHeader = () => {
    const header = document.querySelector(".site-header");
    if (!header) return;

    const updateHeader = () => {
      const showHeader = window.innerWidth > 640 || window.scrollY > 32;
      header.classList.toggle("is-visible", showHeader);
      header.classList.toggle("nav-solid", window.scrollY > 48);
    };

    window.addEventListener("scroll", updateHeader, { passive: true });
    window.addEventListener("resize", updateHeader);
    updateHeader();
  };

  const setupReveals = () => {
    const reveals = document.querySelectorAll(".reveal");

    if (!reveals.length) return;

    if (prefersReducedMotion || !("IntersectionObserver" in window)) {
      reveals.forEach((element) => element.classList.add("is-visible"));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      {
        threshold: 0.14,
        rootMargin: "0px 0px -6% 0px",
      }
    );

    reveals.forEach((element) => observer.observe(element));
  };

  const setupFeatureSteps = () => {
    const panels = document.querySelectorAll(".step-panel");
    const dots = document.querySelectorAll(".dot");
    const wrapper = document.querySelector(".features-sticky-wrapper");

    if (!panels.length || !wrapper) return;

    let activeStep = 0;
    let ticking = false;

    const setStep = (nextStep) => {
      if (nextStep === activeStep) return;
      activeStep = nextStep;
      panels.forEach((panel, index) => panel.classList.toggle("active", index === nextStep));
      dots.forEach((dot, index) => dot.classList.toggle("active", index === nextStep));
    };

    const updateStep = () => {
      const rect = wrapper.getBoundingClientRect();
      const totalScroll = Math.max(1, rect.height - window.innerHeight);
      const progress = Math.min(1, Math.max(0, -rect.top / totalScroll));
      const nextStep = Math.min(panels.length - 1, Math.floor(progress * panels.length));

      setStep(nextStep);
      ticking = false;
    };

    const requestUpdate = () => {
      if (ticking) return;
      ticking = true;
      window.requestAnimationFrame(updateStep);
    };

    window.addEventListener("scroll", requestUpdate, { passive: true });
    window.addEventListener("resize", requestUpdate);
    updateStep();
  };

  const setupTiltCards = () => {
    if (prefersReducedMotion || window.matchMedia("(pointer: coarse)").matches) return;

    const cards = document.querySelectorAll(".proof-card, .guide-card, .testimonial-card, .visual-card");

    cards.forEach((card) => {
      card.addEventListener("pointermove", (event) => {
        const rect = card.getBoundingClientRect();
        const x = (event.clientX - rect.left) / rect.width - 0.5;
        const y = (event.clientY - rect.top) / rect.height - 0.5;

        card.style.setProperty("--tilt-x", `${(-y * 4).toFixed(2)}deg`);
        card.style.setProperty("--tilt-y", `${(x * 4).toFixed(2)}deg`);
      });

      card.addEventListener("pointerleave", () => {
        card.style.removeProperty("--tilt-x");
        card.style.removeProperty("--tilt-y");
      });
    });
  };

  normalizeCanonicalUrl();
  setupHeader();
  setupReveals();
  setupFeatureSteps();
  setupTiltCards();
})();
