(() => {
  const {
    filterUrlFor,
    visit
  } = window.PennyLunch;
  const DEFAULT_DEBOUNCE_MS = 300;

  const installAutoSubmit = () => {
    document.querySelectorAll("[data-auto-submit-form]").forEach((form) => {
      if (form.autoSubmitReady) return;

      form.autoSubmitReady = true;
      let timeoutId;

      const submit = (delay) => {
        window.clearTimeout(timeoutId);
        timeoutId = window.setTimeout(() => {
          if (form.dataset.filterRoot) {
            visit(filterUrlFor(form));
          } else if (form.requestSubmit) {
            form.requestSubmit();
          } else {
            form.submit();
          }
        }, delay);
      };

      form.addEventListener("submit", (event) => {
        if (!form.dataset.filterRoot) return;

        event.preventDefault();
        visit(filterUrlFor(form));
      });

      form.addEventListener("input", (event) => {
        if (!event.target.matches("[data-auto-submit-debounce]")) return;

        submit(Number(event.target.dataset.autoSubmitDebounce || DEFAULT_DEBOUNCE_MS));
      });

      form.addEventListener("change", (event) => {
        if (!event.target.closest("[data-auto-submit-on-change]")) return;

        submit(0);
      });
    });
  };

  Object.assign(window.PennyLunch, { installAutoSubmit });
})();
