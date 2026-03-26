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

const normalizeCanonicalUrl = () => {
  const current = new URL(window.location.href);
  const isWebProtocol = current.protocol === "http:" || current.protocol === "https:";

  if (!isWebProtocol) return;

  let changed = false;

  if (current.protocol !== "https:") {
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
  const isProtocolOrHostChange =
    current.protocol !== window.location.protocol ||
    current.host !== window.location.host ||
    current.pathname !== window.location.pathname;

  if (isProtocolOrHostChange) {
    window.location.replace(destination);
    return;
  }

  window.history.replaceState({}, "", destination);
};

normalizeCanonicalUrl();

const reveals = document.querySelectorAll(".reveal");

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
      } else {
        entry.target.classList.remove("is-visible");
      }
    });
  },
  {
    threshold: 0.18,
    rootMargin: "0px 0px -8% 0px",
  }
);

reveals.forEach((element) => observer.observe(element));

const header = document.querySelector(".site-header");
const updateHeaderVisibility = () => {
  if (!header) return;

  if (window.innerWidth <= 640) {
    if (window.scrollY > 32) {
      header.classList.add("visible");
    } else {
      header.classList.remove("visible");
    }
  } else {
    header.classList.add("visible");
  }
};

window.addEventListener("scroll", updateHeaderVisibility, { passive: true });
window.addEventListener("resize", updateHeaderVisibility);
updateHeaderVisibility();
