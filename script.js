const reveals = document.querySelectorAll(".reveal");

const observer = new IntersectionObserver(
  (entries, observerInstance) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observerInstance.unobserve(entry.target);
      }
    });
  },
  {
    threshold: 0.2,
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
