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

const linkPreview = (() => {
  const metaDescription = document.querySelector('meta[name="description"]')?.content || "";
  const previewShell = document.createElement("div");
  previewShell.className = "link-preview";
  previewShell.setAttribute("role", "status");
  previewShell.innerHTML = `
    <div class="link-preview__glow"></div>
    <div class="link-preview__content">
      <div class="link-preview__icon" aria-hidden="true"></div>
      <div class="link-preview__text">
        <p class="link-preview__label">Preview</p>
        <p class="link-preview__title"></p>
        <p class="link-preview__desc"></p>
        <span class="link-preview__url"></span>
      </div>
    </div>
  `;

  const titleEl = previewShell.querySelector(".link-preview__title");
  const descEl = previewShell.querySelector(".link-preview__desc");
  const urlEl = previewShell.querySelector(".link-preview__url");
  const cache = new Map();
  const prefersTouch = window.matchMedia("(hover: none)").matches;

  const shouldSkip = (href) => {
    if (!href) return true;
    return href.startsWith("mailto:") || href.startsWith("tel:") || href.startsWith("javascript:");
  };

  const sectionPreview = (hash) => {
    if (cache.has(hash)) return cache.get(hash);
    const sectionId = hash.replace("#", "");
    const section = document.getElementById(sectionId);
    if (!section) return null;

    const heading = section.querySelector("h2, h3, h1");
    const paragraph = section.querySelector("p");
    const data = {
      title: heading?.textContent?.trim() || "Section preview",
      description: paragraph?.textContent?.trim() || "",
      url: hash,
    };

    cache.set(hash, data);
    return data;
  };

  const buildPreviewData = (anchor) => {
    const href = anchor.getAttribute("href") || "";
    if (shouldSkip(href)) return null;

    if (href.startsWith("#")) {
      return sectionPreview(href);
    }

    return {
      title: anchor.getAttribute("aria-label") || anchor.textContent.trim() || "Open link",
      description: anchor.dataset.preview || metaDescription,
      url: href,
    };
  };

  const positionPreview = (anchor) => {
    const rect = anchor.getBoundingClientRect();
    const top = rect.bottom + window.scrollY + 12;
    const idealLeft = rect.left + window.scrollX;

    previewShell.style.visibility = "hidden";
    previewShell.style.display = "block";
    const width = previewShell.offsetWidth;
    const maxLeft = window.scrollX + document.documentElement.clientWidth - width - 16;
    const minLeft = window.scrollX + 12;
    const clampedLeft = Math.min(Math.max(idealLeft, minLeft), maxLeft);

    previewShell.style.top = `${top}px`;
    previewShell.style.left = `${clampedLeft}px`;
    previewShell.style.visibility = "";
  };

  const show = (anchor) => {
    const data = buildPreviewData(anchor);
    if (!data) return;

    titleEl.textContent = data.title;
    descEl.textContent = data.description;
    urlEl.textContent = data.url;
    positionPreview(anchor);
    previewShell.classList.add("is-visible");
  };

  const hide = () => {
    previewShell.classList.remove("is-visible");
  };

  const attach = () => {
    if (prefersTouch) return;
    document.body.appendChild(previewShell);

    const anchors = Array.from(document.querySelectorAll("a")).filter(
      (anchor) => !shouldSkip(anchor.getAttribute("href"))
    );

    anchors.forEach((anchor) => {
      anchor.addEventListener("mouseenter", () => show(anchor));
      anchor.addEventListener("focus", () => show(anchor));
      anchor.addEventListener("mouseleave", hide);
      anchor.addEventListener("blur", hide);
    });
  };

  return { attach };
})();

linkPreview.attach();
