(() => {
  const ingredientStorageKeys = {
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

  const storedIngredientNames = () => {
    try {
      const parsed = JSON.parse(readStorage(ingredientStorageKeys.selected) || "[]");
      if (Array.isArray(parsed)) return parsed.map((name) => name.toString().trim()).filter(Boolean);
    } catch {
    }

    return splitIngredientText(readStorage(ingredientStorageKeys.text) || "");
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
    const limit = Number(element.dataset.visibleLimit || 8);

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

  const categorySlugsFor = (form) => {
    try {
      return JSON.parse(form.dataset.categorySlugs || "{}");
    } catch {
      return {};
    }
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

  const initBasecoat = () => {
    if (window.basecoat) window.basecoat.initAll();
  };

  const setTurboLoading = (loading) => {
    document.documentElement.toggleAttribute("data-turbo-loading", loading);
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

  const setIngredientsFabOpen = (root, open) => {
    const panel = root.querySelector("[data-ingredients-filter-panel]");
    const trigger = root.querySelector("[data-ingredients-fab-trigger]");
    const input = root.querySelector("[data-ingredients-filter-input]");
    const optionsElement = root.querySelector("[data-ingredients-filter-options]");

    if (!panel || !trigger || !input) return;

    panel.hidden = !open;
    trigger.setAttribute("aria-expanded", open ? "true" : "false");
    root.dataset.open = open ? "true" : "false";

    if (open) {
      input.focus();
    } else if (optionsElement) {
      optionsElement.hidden = true;
      optionsElement.innerHTML = "";
      input.setAttribute("aria-expanded", "false");
    }
  };

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

        submit(Number(event.target.dataset.autoSubmitDebounce || 300));
      });

      form.addEventListener("change", (event) => {
        if (!event.target.closest("[data-auto-submit-on-change]")) return;

        submit(0);
      });
    });
  };

  const installIngredientsFab = () => {
    document.querySelectorAll("[data-ingredients-fab]").forEach((root) => {
      if (root.ingredientsFabReady) return;

      const currentForm = () => document.querySelector("[data-auto-submit-form]");
      const currentHidden = () => currentForm()?.querySelector("[data-ingredients-filter-hidden]");
      const trigger = root.querySelector("[data-ingredients-fab-trigger]");
      const panel = root.querySelector("[data-ingredients-filter-panel]");
      const input = root.querySelector("[data-ingredients-filter-input]");
      const optionsElement = root.querySelector("[data-ingredients-filter-options]");
      const selectedList = root.querySelector("[data-ingredients-selected-list]");
      const enabledInput = root.querySelector("[data-ingredients-filter-enabled]");
      const enabledControl = enabledInput?.closest("[data-state]");
      const enabledText = root.querySelector("[data-ingredients-enable-text]");
      const status = root.querySelector("[data-ingredients-fab-status]");

      if (!trigger || !panel || !input || !optionsElement || !selectedList || !enabledInput || !enabledControl || !enabledText || !status) return;

      root.ingredientsFabReady = true;

      const optionNames = (() => {
        try {
          return JSON.parse(root.dataset.ingredientOptions || "[]").map((name) => name.toString().trim()).filter(Boolean);
        } catch {
          return [];
        }
      })();
      const optionByKey = new Map(optionNames.map((name) => [name.toLowerCase(), name]));
      const currentIngredients = (root.dataset.currentIngredients || "").trim();
      const storedSelected = (() => {
        try {
          const parsed = JSON.parse(readStorage(ingredientStorageKeys.selected) || "[]");
          if (Array.isArray(parsed)) return parsed;
        } catch {
          return [];
        }

        return [];
      })();
      const storedText = readStorage(ingredientStorageKeys.text) || "";
      const storedEnabled = readStorage(ingredientStorageKeys.enabled) === "true";
      const selected = [];
      let initialized = false;
      let timeoutId;
      let activeOptionIndex = -1;

      const canonicalName = (value) => optionByKey.get(value.toString().trim().toLowerCase());
      const selectedKeys = () => new Set(selected.map((name) => name.toLowerCase()));
      const optionRank = (name, query) => {
        const key = name.toLowerCase();
        const words = key.split(/\s+/);

        if (key === query) return 0;
        if (key.startsWith(query)) return 1;
        if (words.includes(query)) return 2;
        if (words.some((word) => word.startsWith(query))) return 3;
        if (key.includes(query)) return 4;

        return null;
      };

      const seedSelected = (values) => {
        values.forEach((value) => {
          const name = canonicalName(value);
          if (name && !selectedKeys().has(name.toLowerCase())) selected.push(name);
        });
      };

      if (present(currentIngredients)) {
        seedSelected(splitIngredientText(currentIngredients));
      } else if (storedSelected.length > 0) {
        seedSelected(storedSelected);
      } else {
        seedSelected(splitIngredientText(storedText));
      }

      enabledInput.checked = present(currentIngredients) || storedEnabled;

      const setOpen = (open) => {
        setIngredientsFabOpen(root, open);
      };

      const availableOptions = (query) => {
        const selectedKeySet = selectedKeys();
        const normalizedQuery = query.trim().toLowerCase();

        return optionNames
          .filter((name) => !selectedKeySet.has(name.toLowerCase()))
          .map((name) => [name, optionRank(name, normalizedQuery)])
          .filter(([, rank]) => rank !== null)
          .sort(([leftName, leftRank], [rightName, rightRank]) => {
            if (leftRank !== rightRank) return leftRank - rightRank;
            if (leftName.length !== rightName.length) return leftName.length - rightName.length;

            return leftName.localeCompare(rightName);
          })
          .map(([name]) => name)
          .slice(0, 30);
      };

      const hideOptions = () => {
        optionsElement.hidden = true;
        optionsElement.innerHTML = "";
        input.setAttribute("aria-expanded", "false");
        activeOptionIndex = -1;
      };

      const renderOptions = () => {
        const query = input.value.trim();

        optionsElement.innerHTML = "";

        if (query === "") {
          hideOptions();
          return;
        }

        const matches = availableOptions(query);
        activeOptionIndex = matches.length > 0 ? 0 : -1;

        if (matches.length === 0) {
          const empty = document.createElement("div");
          empty.className = "recipe-ingredients-option text-muted-foreground";
          empty.textContent = "No matching ingredient";
          empty.setAttribute("aria-disabled", "true");
          optionsElement.append(empty);
        } else {
          matches.forEach((name, index) => {
            const option = document.createElement("button");
            option.type = "button";
            option.className = "recipe-ingredients-option w-full text-left";
            option.dataset.value = name;
            option.dataset.active = index === activeOptionIndex ? "true" : "false";
            option.setAttribute("role", "option");
            option.setAttribute("aria-selected", index === activeOptionIndex ? "true" : "false");
            option.textContent = name;
            option.addEventListener("mousedown", (event) => {
              event.preventDefault();
              addIngredient(name, { submit: true });
            });
            optionsElement.append(option);
          });
        }

        optionsElement.hidden = false;
        input.setAttribute("aria-expanded", "true");
      };

      const setActiveOption = (nextIndex) => {
        const options = Array.from(optionsElement.querySelectorAll("[role='option']"));
        if (options.length === 0) return;

        activeOptionIndex = (nextIndex + options.length) % options.length;
        options.forEach((option, index) => {
          const active = index === activeOptionIndex;
          option.dataset.active = active ? "true" : "false";
          option.setAttribute("aria-selected", active ? "true" : "false");
        });
      };

      const setStatus = () => {
        const hasSelected = selected.length > 0;
        const enabled = enabledInput.checked;
        const state = enabled ? "enabled" : "disabled";

        trigger.dataset.state = state;
        enabledControl.dataset.state = state;
        enabledText.textContent = enabled ? "On" : "Off";

        if (enabled && hasSelected) {
          status.textContent = `Filtering with ${selected.length} selected`;
        } else if (enabled) {
          status.textContent = "On, add matches";
        } else if (hasSelected) {
          status.textContent = `${selected.length} saved, off`;
        } else {
          status.textContent = "Add what you have";
        }

        trigger.setAttribute("aria-label", `Ingredients: ${status.textContent.toLowerCase()}`);
        trigger.dataset.tooltip = `Ingredients: ${status.textContent.toLowerCase()}`;
      };

      const renderSelected = () => {
        selectedList.innerHTML = "";

        selected.forEach((name) => {
          const chip = document.createElement("span");
          chip.className = "recipe-ingredients-chip";

          const label = document.createElement("span");
          label.textContent = name;

          const remove = document.createElement("button");
          remove.type = "button";
          remove.setAttribute("aria-label", `Remove ${name}`);
          remove.textContent = "x";
          remove.addEventListener("click", () => removeIngredient(name));

          chip.append(label, remove);
          selectedList.append(chip);
        });
      };

      const sync = ({ submit = false, delay = 0 } = {}) => {
        const enabled = enabledInput.checked;
        const text = selected.join("\n");
        const hidden = currentHidden();

        if (hidden) hidden.value = enabled ? text : "";
        writeStorage(ingredientStorageKeys.selected, JSON.stringify(selected));
        writeStorage(ingredientStorageKeys.text, text);
        writeStorage(ingredientStorageKeys.enabled, enabled ? "true" : "false");
        renderSelected();
        setStatus();
        applyIngredientMatches();

        if (!submit || !initialized || !currentForm()) return;

        window.clearTimeout(timeoutId);
        timeoutId = window.setTimeout(() => submitFilterForm(currentForm(), { frame: "recipe-results-frame" }), delay);
      };

      function addIngredient(value, { submit = false } = {}) {
        const name = canonicalName(value);
        if (!name || selectedKeys().has(name.toLowerCase())) return;

        selected.push(name);
        input.value = "";
        hideOptions();
        sync({ submit: enabledInput.checked && submit, delay: 250 });
      }

      function removeIngredient(value) {
        const key = value.toLowerCase();
        const index = selected.findIndex((name) => name.toLowerCase() === key);
        if (index === -1) return;

        selected.splice(index, 1);
        renderOptions();
        sync({ submit: enabledInput.checked, delay: 250 });
      }

      sync();
      initialized = true;
      setOpen(false);

      if (!present(currentIngredients) && present(currentHidden()?.value)) {
        window.setTimeout(() => submitFilterForm(currentForm()), 0);
      }

      trigger.addEventListener("click", () => setOpen(panel.hidden));

      input.addEventListener("input", renderOptions);

      input.addEventListener("keydown", (event) => {
        if (event.key === "ArrowDown") {
          event.preventDefault();
          setActiveOption(activeOptionIndex + 1);
          return;
        }

        if (event.key === "ArrowUp") {
          event.preventDefault();
          setActiveOption(activeOptionIndex - 1);
          return;
        }

        if (event.key === "Enter") {
          event.preventDefault();
          const active = optionsElement.querySelector("[data-active='true']");
          const exact = canonicalName(input.value);
          addIngredient(active?.dataset.value || exact || "", { submit: true });
        }
      });

      input.addEventListener("blur", () => {
        window.setTimeout(hideOptions, 120);
      });

      enabledInput.addEventListener("change", () => {
        sync({ submit: selected.length > 0 });
      });

      root.addEventListener("keydown", (event) => {
        if (event.key === "Escape") setOpen(false);
      });
    });
  };

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
    if (Object.values(ingredientStorageKeys).includes(event.key)) applyIngredientMatches();
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
