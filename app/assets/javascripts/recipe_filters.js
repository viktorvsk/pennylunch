(() => {
  const {
    BASKET_CHANGE_EVENT,
    applyIngredientMatches,
    initBasecoat,
    installAutoSubmit,
    installIngredientsFab,
    setIngredientsFabOpen,
    setTurboLoading
  } = window.PennyLunch;

  const install = ({ forceBasecoat = false } = {}) => {
    initBasecoat({ force: forceBasecoat });
    installAutoSubmit();
    installIngredientsFab();
    applyIngredientMatches();
  };

  document.addEventListener("DOMContentLoaded", install);
  document.addEventListener("turbo:load", () => install({ forceBasecoat: true }));
  document.addEventListener("turbo:render", () => {
    initBasecoat({ force: true });
    applyIngredientMatches();
  });
  document.addEventListener("turbo:frame-render", () => {
    initBasecoat({ force: true });
    applyIngredientMatches();
  });
  document.addEventListener("recipes:updated", () => applyIngredientMatches());
  window.addEventListener(BASKET_CHANGE_EVENT, () => applyIngredientMatches());
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
