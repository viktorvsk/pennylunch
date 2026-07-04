(() => {
  const {
    STORAGE_KEYS,
    readStorage,
    normalizeIngredientName,
    splitIngredientText
  } = window.PennyLunch;
  const DEFAULT_VISIBLE_INGREDIENT_LIMIT = 8;

  const storedIngredientNames = () => {
    try {
      const parsed = JSON.parse(readStorage(STORAGE_KEYS.selected) || "[]");
      if (Array.isArray(parsed)) return parsed.map((name) => name.toString().trim()).filter(Boolean);
    } catch {
    }

    return splitIngredientText(readStorage(STORAGE_KEYS.text) || "");
  };

  const storedIngredientKeys = () => storedIngredientNames().map(normalizeIngredientName);

  const ingredientMatches = (name, selectedKeys) => {
    const key = normalizeIngredientName(name);
    return selectedKeys.includes(key);
  };

  const ingredientMatchRank = (name, selectedKeys) => {
    const key = normalizeIngredientName(name);
    const index = selectedKeys.indexOf(key);
    return index >= 0 ? index : Number.POSITIVE_INFINITY;
  };

  const recipeIngredientNamesFor = (element) => {
    try {
      const parsed = JSON.parse(element.dataset.ingredientNames || "[]");
      if (Array.isArray(parsed)) return parsed.map((name) => name.toString().trim()).filter(Boolean);
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
    const names = recipeIngredientNamesFor(element);
    const limit = Number(element.dataset.visibleLimit || DEFAULT_VISIBLE_INGREDIENT_LIMIT);
    const ordered = names.slice().sort((left, right) => {
      const leftRank = ingredientMatchRank(left, selectedKeys);
      const rightRank = ingredientMatchRank(right, selectedKeys);
      if (leftRank !== rightRank) return leftRank - rightRank;

      return names.indexOf(left) - names.indexOf(right);
    });
    const visibleNames = ordered.slice(0, limit);
    const remainingCount = ordered.length - visibleNames.length;

    element.replaceChildren();
    visibleNames.forEach((name, index) => {
      if (index > 0) element.append(document.createTextNode(", "));
      element.append(renderIngredientName(name, ingredientMatches(name, selectedKeys)));
    });
    if (remainingCount > 0) element.append(document.createTextNode(` + ${remainingCount} more`));
  };

  const applyIngredientMatches = (root = document) => {
    const selectedKeys = storedIngredientKeys();

    root.querySelectorAll("[data-recipe-ingredients]").forEach((element) => {
      renderRecipeIngredientSummary(element, selectedKeys);
    });

    root.querySelectorAll("[data-ingredient-name]").forEach((element) => {
      element.classList.toggle("recipe-ingredient-match", ingredientMatches(element.dataset.ingredientName || element.textContent, selectedKeys));
    });
  };

  Object.assign(window.PennyLunch, {
    applyIngredientMatches,
    ingredientMatches,
    storedIngredientKeys
  });
})();
