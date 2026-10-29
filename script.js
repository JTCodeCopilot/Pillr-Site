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

  // Keep the approved Apple campaign link for visitors arriving from the Meta ad.
  // This reads the landing-page marker only; no cookies or browser storage are used.
  const setupMetaCampaignLinks = () => {
    const current = new URL(window.location.href);
    if (current.searchParams.get("ref") !== "meta-paid") return;

    document.querySelectorAll("a[href]").forEach((link) => {
      const destination = new URL(link.href, current);
      if (
        destination.hostname === "apps.apple.com" &&
        /\/id6746717689\/?$/.test(destination.pathname)
      ) {
        destination.searchParams.set("pt", "127431610");
        destination.searchParams.set("ct", "Meta Paid");
        destination.searchParams.set("mt", "8");
        link.href = destination.href;
      }
    });
  };

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
    const isLandingHeader = header.classList.contains("landing-header");

    const updateHeader = () => {
      const showHeader = !isLandingHeader || window.scrollY > 16;
      header.classList.toggle("is-visible", showHeader);
      header.classList.toggle("nav-solid", isLandingHeader ? showHeader : window.scrollY > 48);
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

  setupMetaCampaignLinks();
  normalizeCanonicalUrl();
  setupHeader();
  setupReveals();
})();
