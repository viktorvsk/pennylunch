(() => {
  const namespace = window.PennyLunch || {};
  const STORAGE_KEYS = {
    enabled: "pennylunch.ingredients.enabled",
    selected: "pennylunch.ingredients.selected",
    text: "pennylunch.ingredients.text"
  };

  const present = (value) => value && value.toString().trim() !== "";

  const readStorage = (key) => {
    try {
      return window.localStorage.getItem(key);
    } catch {
      return null;
    }
  };

  const writeStorage = (key, value) => {
    try {
      window.localStorage.setItem(key, value);
    } catch {
      return null;
    }
  };

  const normalizeIngredientName = (value) => value.toString().trim().replace(/\s+/g, " ").toLowerCase();

  const splitIngredientText = (text) => text.split(/[\n,;]+/).map((name) => name.trim()).filter(Boolean);

  const recipeUiCatalog = () => {
    const element = document.querySelector("[data-recipe-ui-catalog]");

    if (!element) return {};

    try {
      return JSON.parse(element.textContent || "{}");
    } catch {
      return {};
    }
  };

  const categorySlugsFor = (form) => {
    const slugs = recipeUiCatalog().categorySlugs;
    if (slugs && typeof slugs === "object") return slugs;

    try {
      return JSON.parse(form.dataset.categorySlugs || "{}");
    } catch {
      return {};
    }
  };

  const recipeIngredientOptions = () => {
    const options = recipeUiCatalog().ingredientOptions;
    return Array.isArray(options) ? options : [];
  };

  const filterUrlFor = (form) => {
    const root = new URL(form.dataset.filterRoot || form.action, window.location.origin);
    const rootPath = root.pathname.replace(/\/$/, "");
    const formData = new FormData(form);
    const category = formData.get("category")?.toString().trim() || "";
    const categorySlug = categorySlugsFor(form)[category];
    const url = new URL(rootPath, window.location.origin);

    if (category && categorySlug) {
      url.pathname = `${rootPath}/${categorySlug}`;
    }

    formData.forEach((value, key) => {
      if (key === "category" || key === "page") return;
      if (!present(value)) return;
      if (key === "sort" && value === "time_asc") return;

      url.searchParams.set(key, value);
    });

    return url.toString();
  };

  const visit = (url) => {
    if (window.Turbo?.visit) {
      window.Turbo.visit(url);
    } else {
      window.location.assign(url);
    }
  };

  const submitFilterForm = (form, { frame } = {}) => {
    if (!form) return;

    const url = filterUrlFor(form);

    if (frame && window.Turbo?.visit) {
      window.Turbo.visit(url, { frame });
    } else {
      visit(url);
    }
  };

  const initBasecoat = () => {
    if (window.basecoat) window.basecoat.initAll();
  };

  const setTurboLoading = (loading) => {
    document.documentElement.toggleAttribute("data-turbo-loading", loading);
  };

  window.PennyLunch = {
    ...namespace,
    STORAGE_KEYS,
    present,
    readStorage,
    writeStorage,
    normalizeIngredientName,
    splitIngredientText,
    recipeIngredientOptions,
    recipeUiCatalog,
    filterUrlFor,
    visit,
    submitFilterForm,
    initBasecoat,
    setTurboLoading
  };
})();
