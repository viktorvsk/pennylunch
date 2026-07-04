(() => {
  const {
    applyIngredientMatches,
    normalizeIngredientName,
    present,
    recipeIngredientOptions,
    readBasket,
    splitIngredientText,
    submitFilterForm,
    writeBasket
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
      if (root.ingredientsFabReady) {
        root.refreshIngredientsFab?.();
        return;
      }

      const currentForm = () => document.querySelector("[data-auto-submit-form]");
      const currentHidden = () => currentForm()?.querySelector("[data-ingredients-filter-hidden]");
      const trigger = root.querySelector("[data-ingredients-fab-trigger]");
      const panel = root.querySelector("[data-ingredients-filter-panel]");
      const input = root.querySelector("[data-ingredients-filter-input]");
      const addButton = root.querySelector("[data-ingredients-add-button]");
      const optionsElement = root.querySelector("[data-ingredients-filter-options]");
      const selectedList = root.querySelector("[data-ingredients-selected-list]");
      const enabledInput = root.querySelector("[data-ingredients-filter-enabled]");
      const enabledControl = enabledInput?.closest("[data-state]");
      const enabledText = root.querySelector("[data-ingredients-enable-text]");
      const status = root.querySelector("[data-ingredients-fab-status]");

      if (!trigger || !panel || !input || !addButton || !optionsElement || !selectedList || !enabledInput || !enabledControl || !enabledText || !status) return;

      root.ingredientsFabReady = true;

      const optionRecords = (() => {
        const rawOptions = root.dataset.ingredientOptions || JSON.stringify(recipeIngredientOptions());

        try {
          return JSON.parse(rawOptions).map((option) => {
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
      const storedBasket = readBasket();
      const selected = [];
      let initialized = false;
      let timeoutId;
      let activeOptionIndex = NO_OPTION_INDEX;

      const optionFor = (value) => optionByKey.get(normalizeIngredientName(value));
      const canonicalName = (value) => optionFor(value)?.name;
      const optionalIngredient = (value) => optionFor(value)?.optional === true;
      const filterableSelected = () => selected.filter((name) => !optionalIngredient(name));
      const selectedForDisplay = () => [...selected].sort((left, right) => Number(optionalIngredient(left)) - Number(optionalIngredient(right)));
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

      if (storedBasket.selected.length > 0) {
        seedSelected(storedBasket.selected);
      }
      if (present(currentIngredients)) {
        seedSelected(splitIngredientText(currentIngredients));
      }

      enabledInput.checked = present(currentIngredients) || storedBasket.enabled;

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
        setAddButtonState();
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
        setAddButtonState();
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
        setAddButtonState();
      };

      function addButtonValue() {
        const query = input.value.trim();
        if (query === "") return "";

        const active = optionsElement.hidden ? null : optionsElement.querySelector("[data-active='true']");
        if (active?.dataset.value) return active.dataset.value;

        const exact = canonicalName(query);
        if (exact && !selectedKeys().has(normalizeIngredientName(exact))) return exact;

        return availableOptions(query)[0] || "";
      }

      function setAddButtonState() {
        const value = addButtonValue();

        addButton.disabled = value === "";
        addButton.dataset.state = value === "" ? "empty" : "ready";
      }

      const setStatus = () => {
        const hasSelected = selected.length > 0;
        const enabled = enabledInput.checked;
        const state = enabled ? "enabled" : "disabled";

        trigger.dataset.state = state;
        enabledControl.dataset.state = state;
        enabledText.textContent = enabled ? "On" : "Off";

        if (enabled && filterableSelected().length > 0) {
          status.textContent = `Filtering with ${filterableSelected().length} selected`;
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

        selectedForDisplay().forEach((name) => {
          const row = document.createElement("div");
          row.className = "recipe-ingredients-row";
          row.dataset.optional = optionalIngredient(name) ? "true" : "false";

          const label = document.createElement("span");
          label.textContent = name;

          const remove = document.createElement("button");
          remove.type = "button";
          remove.className = "recipe-ingredients-remove";
          remove.setAttribute("aria-label", `Remove ${name}`);
          remove.addEventListener("click", () => removeIngredient(name));

          row.append(label, remove);
          selectedList.append(row);
        });
      };

      const sync = ({ submit = false, delay = 0 } = {}) => {
        const enabled = enabledInput.checked;
        const filterText = selected.filter((name) => !optionalIngredient(name)).join("\n");
        const hidden = currentHidden();

        if (hidden) hidden.value = enabled ? filterText : "";
        writeBasket({ selected, enabled });
        renderSelected();
        setStatus();
        applyIngredientMatches();

        if (!submit || !initialized || !currentForm()) return;

        window.clearTimeout(timeoutId);
        timeoutId = window.setTimeout(() => submitFilterForm(currentForm(), { frame: "recipe-results-frame" }), delay);
      };

      const refreshPageContext = () => {
        sync();
      };

      root.refreshIngredientsFab = refreshPageContext;

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
      setAddButtonState();

      trigger.addEventListener("click", () => setOpen(panel.hidden));
      addButton.addEventListener("click", () => addIngredient(addButtonValue(), { submit: true }));
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
          addIngredient(addButtonValue(), { submit: true });
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
