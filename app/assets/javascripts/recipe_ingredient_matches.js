(() => {
  const {
    normalizeIngredientName,
    readBasket,
    splitIngredientText
  } = window.PennyLunch;
  const DEFAULT_VISIBLE_INGREDIENT_LIMIT = 8;

  const storedIngredientNames = () => {
    const basket = readBasket();
    if (!basket.enabled) return [];

    return basket.selected.map((name) => name.toString().trim()).filter(Boolean);
  };

  const activeIngredientNames = () => {
    const hidden = document.querySelector("[data-auto-submit-form] [data-ingredients-filter-hidden]");
    if (hidden) return splitIngredientText(hidden.value || "");

    return storedIngredientNames();
  };

  const activeIngredientKeys = () => activeIngredientNames().map(normalizeIngredientName);

  const matchNamesFor = (entry) => (Array.isArray(entry.matchNames) && entry.matchNames.length > 0 ? entry.matchNames : [entry.matchName]);

  const ingredientMatches = (entry, selectedKeys) => {
    return matchNamesFor(entry).some((name) => selectedKeys.includes(normalizeIngredientName(name || "")));
  };

  const ingredientMatchRank = (entry, selectedKeys) => {
    const indexes = matchNamesFor(entry)
      .map((name) => selectedKeys.indexOf(normalizeIngredientName(name || "")))
      .filter((index) => index >= 0);
    return indexes.length > 0 ? Math.min(...indexes) : Number.POSITIVE_INFINITY;
  };

  const recipeIngredientEntriesFor = (element) => {
    try {
      const parsed = JSON.parse(element.dataset.ingredientNames || "[]");
      const catalogNames = JSON.parse(element.dataset.ingredientCatalogNames || "[]");
      if (Array.isArray(parsed)) {
        return parsed.map((name, index) => {
          const displayName = name.toString().trim();
          const catalogName = Array.isArray(catalogNames) && catalogNames[index] ? catalogNames[index].toString().trim() : "";
          return { name: displayName, matchName: catalogName || displayName };
        }).filter((entry) => entry.name);
      }
    } catch {
    }

    return [];
  };

  const renderIngredientName = (name, matched) => {
    if (!matched) return document.createTextNode(name);

    const element = document.createElement("span");
    element.className = "recipe-ingredient-match";
    element.textContent = name;
    return element;
  };

  const renderRecipeIngredientSummary = (element, selectedKeys) => {
    const entries = recipeIngredientEntriesFor(element);
    const limit = Number(element.dataset.visibleLimit || DEFAULT_VISIBLE_INGREDIENT_LIMIT);
    const ordered = entries.slice().sort((left, right) => {
      const leftRank = ingredientMatchRank(left, selectedKeys);
      const rightRank = ingredientMatchRank(right, selectedKeys);
      if (leftRank !== rightRank) return leftRank - rightRank;

      return entries.indexOf(left) - entries.indexOf(right);
    });
    const visibleEntries = ordered.slice(0, limit);
    const remainingCount = ordered.length - visibleEntries.length;

    element.replaceChildren();
    visibleEntries.forEach((entry, index) => {
      if (index > 0) element.append(document.createTextNode(", "));
      element.append(renderIngredientName(entry.name, ingredientMatches(entry, selectedKeys)));
    });
    if (remainingCount > 0) element.append(document.createTextNode(` + ${remainingCount} more`));
  };

  const applyIngredientMatches = (root = document) => {
    const selectedKeys = activeIngredientKeys();

    root.querySelectorAll("[data-recipe-ingredients]").forEach((element) => {
      renderRecipeIngredientSummary(element, selectedKeys);
    });

    root.querySelectorAll("[data-ingredient-name]").forEach((element) => {
      let matchNames = [];
      try {
        matchNames = JSON.parse(element.dataset.ingredientMatchNames || "[]");
      } catch {
        matchNames = [];
      }

      const matched = ingredientMatches({ matchName: element.dataset.ingredientMatchName || element.dataset.ingredientName || element.textContent, matchNames }, selectedKeys);
      const row = element.closest("[data-recipe-ingredient-row]");

      if (row) {
        row.classList.toggle("recipe-ingredient-row--matched", matched);
        element.classList.remove("recipe-ingredient-match");
      } else {
        element.classList.toggle("recipe-ingredient-match", matched);
      }
    });
  };

  Object.assign(window.PennyLunch, {
    activeIngredientKeys,
    applyIngredientMatches,
    ingredientMatches
  });
})();
