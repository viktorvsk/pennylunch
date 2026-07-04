(() => {
  const NEAR_VIEWPORT_MARGIN_PX = 600;

  const nearViewport = (element) => {
    const rect = element.getBoundingClientRect();
    return rect.top < window.innerHeight + NEAR_VIEWPORT_MARGIN_PX;
  };

  const appendNextPage = async (sentinel) => {
    if (sentinel.dataset.loading === "true") return;

    const nextUrl = sentinel.dataset.nextUrl;
    if (!nextUrl) {
      sentinel.remove();
      return;
    }

    sentinel.dataset.loading = "true";

    try {
      const response = await fetch(nextUrl, {
        headers: { Accept: "text/html" },
        credentials: "same-origin"
      });

      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const html = await response.text();
      const documentFragment = new DOMParser().parseFromString(html, "text/html");
      const nextResults = documentFragment.querySelector("#recipe-results");
      const currentResults = document.querySelector("#recipe-results");
      const nextSentinel = documentFragment.querySelector("[data-infinite-scroll-sentinel]");

      if (!nextResults || !currentResults) {
        sentinel.remove();
        return;
      }

      currentResults.append(...Array.from(nextResults.children));
      document.dispatchEvent(new CustomEvent("recipes:updated"));

      if (window.basecoat) {
        window.basecoat.initAll();
      }

      if (nextSentinel?.dataset.nextUrl) {
        sentinel.dataset.nextUrl = nextSentinel.dataset.nextUrl;
        sentinel.dataset.loading = "false";
        if (nearViewport(sentinel)) appendNextPage(sentinel);
      } else {
        sentinel.remove();
      }
    } catch {
      sentinel.dataset.loading = "false";
      const status = sentinel.querySelector("[data-infinite-scroll-status]");
      if (status) status.textContent = "Scroll to retry loading more recipes.";
    }
  };

  const installInfiniteScroll = () => {
    document.querySelectorAll("[data-infinite-scroll-sentinel]").forEach((sentinel) => {
      if (sentinel.dataset.infiniteScrollReady === "true") return;

      sentinel.dataset.infiniteScrollReady = "true";

      if (!("IntersectionObserver" in window)) {
        appendNextPage(sentinel);
        return;
      }

      const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) appendNextPage(sentinel);
        });
      }, { rootMargin: `${NEAR_VIEWPORT_MARGIN_PX}px 0px` });

      observer.observe(sentinel);
    });
  };

  document.addEventListener("DOMContentLoaded", installInfiniteScroll);
  document.addEventListener("turbo:load", installInfiniteScroll);
})();
