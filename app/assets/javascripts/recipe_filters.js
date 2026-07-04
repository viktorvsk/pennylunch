(() => {
  const {
    STORAGE_KEYS,
    applyIngredientMatches,
    initBasecoat,
    installAutoSubmit,
    installIngredientsFab,
    setIngredientsFabOpen,
    setTurboLoading
  } = window.PennyLunch;

  const install = () => {
    initBasecoat();
    installAutoSubmit();
    installIngredientsFab();
    applyIngredientMatches();
  };

  document.addEventListener("DOMContentLoaded", install);
  document.addEventListener("turbo:load", install);
  document.addEventListener("turbo:render", () => applyIngredientMatches());
  document.addEventListener("turbo:frame-render", () => applyIngredientMatches());
  document.addEventListener("recipes:updated", () => applyIngredientMatches());
  window.addEventListener("storage", (event) => {
    if (Object.values(STORAGE_KEYS).includes(event.key)) applyIngredientMatches();
  });
  document.addEventListener("pointerdown", (event) => {
    document.querySelectorAll("[data-ingredients-fab]").forEach((root) => {
      if (root.contains(event.target)) return;

      setIngredientsFabOpen(root, false);
    });
  });
  document.addEventListener("turbo:visit", () => setTurboLoading(true));
  document.addEventListener("turbo:before-render", () => setTurboLoading(false));
  document.addEventListener("turbo:load", () => setTurboLoading(false));
  document.addEventListener("turbo:fetch-request-error", () => setTurboLoading(false));
})();
