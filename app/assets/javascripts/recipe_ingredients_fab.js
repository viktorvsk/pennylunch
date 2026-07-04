(() => {
  const {
    STORAGE_KEYS,
    applyIngredientMatches,
    normalizeIngredientName,
    present,
    readStorage,
    splitIngredientText,
    submitFilterForm,
    writeStorage
  } = window.PennyLunch;
  const FIRST_OPTION_INDEX = 0;
  const NO_OPTION_INDEX = -1;
  const MAX_OPTION_COUNT = 30;
  const OPTION_BLUR_DELAY_MS = 120;
  const SUBMIT_DELAY_MS = 250;

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

      const optionRecords = (() => {
        try {
          return JSON.parse(root.dataset.ingredientOptions || "[]").map((option) => {
            if (typeof option === "string") return { name: option.trim(), optional: false };

            return { name: option.name?.toString().trim() || "", optional: option.optional === true };
          }).filter((option) => option.name !== "");
        } catch {
          return [];
        }
      })();
      const optionNames = optionRecords.map((option) => option.name);
      const optionByKey = new Map(optionRecords.map((option) => [normalizeIngredientName(option.name), option]));
      const currentIngredients = (root.dataset.currentIngredients || "").trim();
      const storedSelected = (() => {
        try {
          const parsed = JSON.parse(readStorage(STORAGE_KEYS.selected) || "[]");
          if (Array.isArray(parsed)) return parsed;
        } catch {
          return [];
        }

        return [];
      })();
      const storedText = readStorage(STORAGE_KEYS.text) || "";
      const storedEnabled = readStorage(STORAGE_KEYS.enabled) === "true";
      const selected = [];
      let initialized = false;
      let timeoutId;
      let activeOptionIndex = NO_OPTION_INDEX;

      const optionFor = (value) => optionByKey.get(normalizeIngredientName(value));
      const canonicalName = (value) => optionFor(value)?.name;
      const optionalIngredient = (value) => optionFor(value)?.optional === true;
      const selectedKeys = () => new Set(selected.map(normalizeIngredientName));
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
          if (name && !selectedKeys().has(normalizeIngredientName(name))) selected.push(name);
        });
      };

      if (storedSelected.length > 0) {
        seedSelected(storedSelected);
      }
      if (present(currentIngredients)) {
        seedSelected(splitIngredientText(currentIngredients));
      } else if (selected.length === 0) {
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
          .filter((name) => !selectedKeySet.has(normalizeIngredientName(name)))
          .map((name) => [name, optionRank(name, normalizedQuery)])
          .filter(([, rank]) => rank !== null)
          .sort(([leftName, leftRank], [rightName, rightRank]) => {
            if (leftRank !== rightRank) return leftRank - rightRank;
            if (leftName.length !== rightName.length) return leftName.length - rightName.length;

            return leftName.localeCompare(rightName);
          })
          .map(([name]) => name)
          .slice(0, MAX_OPTION_COUNT);
      };

      const hideOptions = () => {
        optionsElement.hidden = true;
        optionsElement.innerHTML = "";
        input.setAttribute("aria-expanded", "false");
        activeOptionIndex = NO_OPTION_INDEX;
      };

      const renderOptions = () => {
        const query = input.value.trim();

        optionsElement.innerHTML = "";

        if (query === "") {
          hideOptions();
          return;
        }

        const matches = availableOptions(query);
        activeOptionIndex = matches.length > 0 ? FIRST_OPTION_INDEX : NO_OPTION_INDEX;

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
            option.dataset.optional = optionalIngredient(name) ? "true" : "false";
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
        const filterableSelected = selected.filter((name) => !optionalIngredient(name));
        const hasSelected = selected.length > 0;
        const enabled = enabledInput.checked;
        const state = enabled ? "enabled" : "disabled";

        trigger.dataset.state = state;
        enabledControl.dataset.state = state;
        enabledText.textContent = enabled ? "On" : "Off";

        if (enabled && filterableSelected.length > 0) {
          status.textContent = `Filtering with ${filterableSelected.length} selected`;
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
          chip.dataset.optional = optionalIngredient(name) ? "true" : "false";

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
        const filterText = selected.filter((name) => !optionalIngredient(name)).join("\n");
        const hidden = currentHidden();

        if (hidden) hidden.value = enabled ? filterText : "";
        writeStorage(STORAGE_KEYS.selected, JSON.stringify(selected));
        writeStorage(STORAGE_KEYS.text, text);
        writeStorage(STORAGE_KEYS.enabled, enabled ? "true" : "false");
        renderSelected();
        setStatus();
        applyIngredientMatches();

        if (!submit || !initialized || !currentForm()) return;

        window.clearTimeout(timeoutId);
        timeoutId = window.setTimeout(() => submitFilterForm(currentForm(), { frame: "recipe-results-frame" }), delay);
      };

      function addIngredient(value, { submit = false } = {}) {
        const name = canonicalName(value);
        if (!name || selectedKeys().has(normalizeIngredientName(name))) return;

        selected.push(name);
        input.value = "";
        hideOptions();
        sync({ submit: enabledInput.checked && submit, delay: SUBMIT_DELAY_MS });
      }

      function removeIngredient(value) {
        const key = normalizeIngredientName(value);
        const index = selected.findIndex((name) => normalizeIngredientName(name) === key);
        if (index === NO_OPTION_INDEX) return;

        selected.splice(index, 1);
        renderOptions();
        sync({ submit: enabledInput.checked, delay: SUBMIT_DELAY_MS });
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
        window.setTimeout(hideOptions, OPTION_BLUR_DELAY_MS);
      });

      enabledInput.addEventListener("change", () => {
        sync({ submit: selected.length > 0 });
      });

      root.addEventListener("keydown", (event) => {
        if (event.key === "Escape") setOpen(false);
      });
    });
  };

  Object.assign(window.PennyLunch, {
    installIngredientsFab,
    setIngredientsFabOpen
  });
})();
