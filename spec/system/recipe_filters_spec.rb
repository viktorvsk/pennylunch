require "rails_helper"

RSpec.describe "Recipe filters", type: :system do
  let(:expected_title) { "E2E Turbo Filter Tomato Pasta" }
  let(:excluded_titles) do
    [
      "E2E Turbo Filter Slow Tomato Pasta",
      "E2E Turbo Filter Tomato Budget",
      "E2E Turbo Filter Garlic Rice",
      "E2E Turbo Filter Dessert Tomato"
    ]
  end

  before do
    clear_browser_basket
  end

  after do
    clear_browser_basket
  end

  before do
    create(
      :recipe,
      title: expected_title,
      category: "E2E Dinner",
      category_normalized: "e2e dinner",
      prep_time: 5,
      cook_time: 10,
      ratings: 4.99
    )
    create(
      :recipe,
      title: "E2E Turbo Filter Slow Tomato Pasta",
      category: "E2E Dinner",
      category_normalized: "e2e dinner",
      prep_time: 60,
      cook_time: 30,
      ratings: 4.98
    )
    create(
      :recipe,
      title: "E2E Turbo Filter Tomato Budget",
      category: "E2E Dinner",
      category_normalized: "e2e dinner",
      prep_time: 5,
      cook_time: 8,
      ratings: 4.1
    )
    create(
      :recipe,
      title: "E2E Turbo Filter Garlic Rice",
      category: "E2E Dinner",
      category_normalized: "e2e dinner",
      prep_time: 5,
      cook_time: 10,
      ratings: 4.97
    )
    create(
      :recipe,
      title: "E2E Turbo Filter Dessert Tomato",
      category: "E2E Dessert",
      category_normalized: "e2e dessert",
      prep_time: 5,
      cook_time: 10,
      ratings: 4.96
    )
  end

  it "filters relevant recipes through Turbo navigation" do
    visit recipes_path

    find("input[name='q']").set("E2E Turbo Filter Tomato")
    expect(page).to have_current_path(%r{/recipes\?q=E2E\+Turbo\+Filter\+Tomato})

    find("button[aria-label='Category']").click
    find("#recipe-category-popover input").set("E2E Dinner")
    find("[role='option'][data-value='e2e dinner']").click
    expect(page).to have_current_path(%r{/recipes/e2e-dinner\?q=E2E\+Turbo\+Filter\+Tomato})

    find(:xpath, "//label[.//input[@name='quick']]").click
    expect(page).to have_current_path(/quick=1/)
    find(:xpath, "//label[.//input[@name='popular']]").click
    expect(page).to have_current_path(/popular=1/)

    within "#recipe-results-frame" do
      expect(page).to have_text(expected_title)
      excluded_titles.each { |title| expect(page).to have_no_text(title) }
    end

    expect(page).to have_css(".recipe-toolbar-toggle[data-state='active']", count: 2)
    expect(page).to have_css("#recipe-ingredients-fab[data-turbo-permanent]", count: 1)
    expect(page).to have_current_path("/recipes/e2e-dinner", ignore_query: true)
  end

  it "shows the Turbo loading spinner over dimmed content" do
    visit recipes_path

    loading_state = page.evaluate_script(<<~JS)
      (() => {
        document.documentElement.setAttribute("data-turbo-loading", "");

        const toolbar = document.querySelector(".recipe-toolbar").getBoundingClientRect();
        const page = document.querySelector(".recipe-page");
        const fab = document.querySelector("#recipe-ingredients-fab");
        const overlay = document.querySelector(".recipe-content-loading");
        const spinner = document.querySelector(".recipe-content-loading-spinner");
        const overlayStyle = getComputedStyle(overlay);
        const spinnerRect = spinner.getBoundingClientRect();

        return {
          pageOpacity: getComputedStyle(page).opacity,
          pagePointerEvents: getComputedStyle(page).pointerEvents,
          fabOpacity: getComputedStyle(fab).opacity,
          fabPointerEvents: getComputedStyle(fab).pointerEvents,
          overlayOpacity: Number.parseFloat(overlayStyle.opacity),
          overlayVisibility: overlayStyle.visibility,
          overlayTop: Math.round(overlay.getBoundingClientRect().top),
          toolbarBottom: Math.round(toolbar.bottom),
          spinnerHeight: Math.round(spinnerRect.height),
          spinnerWidth: Math.round(spinnerRect.width),
          spinnerCenterX: Math.round(spinnerRect.left + spinnerRect.width / 2),
          spinnerCenterY: Math.round(spinnerRect.top + spinnerRect.height / 2),
          viewportCenterX: Math.round(window.innerWidth / 2),
          contentCenterY: Math.round(toolbar.bottom + ((window.innerHeight - toolbar.bottom) / 2))
        };
      })()
    JS

    expect(loading_state.fetch("pageOpacity")).to eq("0.3")
    expect(loading_state.fetch("pagePointerEvents")).to eq("none")
    expect(loading_state.fetch("fabOpacity")).to eq("0.3")
    expect(loading_state.fetch("fabPointerEvents")).to eq("none")
    expect(loading_state.fetch("overlayOpacity")).to eq(1.0)
    expect(loading_state.fetch("overlayVisibility")).to eq("visible")
    expect(loading_state.fetch("overlayTop")).to eq(loading_state.fetch("toolbarBottom"))
    expect(loading_state.fetch("spinnerHeight")).to be >= 48
    expect(loading_state.fetch("spinnerWidth")).to be >= 48
    expect((loading_state.fetch("spinnerCenterX") - loading_state.fetch("viewportCenterX")).abs).to be <= 2
    expect((loading_state.fetch("spinnerCenterY") - loading_state.fetch("contentCenterY")).abs).to be <= 2

    idle_state = page.evaluate_script(<<~JS)
      (() => {
        document.documentElement.removeAttribute("data-turbo-loading");

        const overlayStyle = getComputedStyle(document.querySelector(".recipe-content-loading"));

        return {
          pageOpacity: getComputedStyle(document.querySelector(".recipe-page")).opacity,
          fabOpacity: getComputedStyle(document.querySelector("#recipe-ingredients-fab")).opacity,
          overlayOpacity: Number.parseFloat(overlayStyle.opacity),
          overlayVisibility: overlayStyle.visibility
        };
      })()
    JS

    expect(idle_state.fetch("pageOpacity")).to eq("1")
    expect(idle_state.fetch("fabOpacity")).to eq("1")
    expect(idle_state.fetch("overlayOpacity")).to eq(0.0)
    expect(idle_state.fetch("overlayVisibility")).to eq("hidden")
  end

  it "renders a subtle branded placeholder behind recipe images" do
    visit recipes_path

    placeholder = page.evaluate_script(<<~JS)
      (() => {
        const frame = document.querySelector(".recipe-card-image");
        const image = frame.querySelector("img");
        const frameStyle = getComputedStyle(frame);
        const imageStyle = getComputedStyle(image);
        const beforeStyle = getComputedStyle(frame, "::before");
        const afterStyle = getComputedStyle(frame, "::after");

        return {
          framePosition: frameStyle.position,
          frameIsolation: frameStyle.isolation,
          beforeBackground: beforeStyle.backgroundImage,
          beforeOpacity: Number.parseFloat(beforeStyle.opacity),
          beforeZIndex: beforeStyle.zIndex,
          afterAnimationName: afterStyle.animationName,
          afterAnimationDuration: afterStyle.animationDuration,
          afterAnimationDirection: afterStyle.animationDirection,
          afterOpacity: Number.parseFloat(afterStyle.opacity),
          afterZIndex: afterStyle.zIndex,
          imagePosition: imageStyle.position,
          imageZIndex: imageStyle.zIndex
        };
      })()
    JS

    expect(placeholder.fetch("framePosition")).to eq("relative")
    expect(placeholder.fetch("frameIsolation")).to eq("isolate")
    expect(placeholder.fetch("beforeBackground")).to include("/icon-512x512.png")
    expect(placeholder.fetch("beforeOpacity")).to eq(0.5)
    expect(placeholder.fetch("beforeZIndex")).to eq("0")
    expect(placeholder.fetch("afterAnimationName")).to eq("recipe-card-image-sweep")
    expect(placeholder.fetch("afterAnimationDuration").to_f).to be >= 3.0
    expect(placeholder.fetch("afterAnimationDirection")).to eq("alternate")
    expect(placeholder.fetch("afterOpacity")).to be <= 0.35
    expect(placeholder.fetch("afterZIndex")).to eq("0")
    expect(placeholder.fetch("imagePosition")).to eq("relative")
    expect(placeholder.fetch("imageZIndex")).to eq("1")
  end

  it "highlights index card ingredients from the active filter context" do
    create(:ingredient, name: "honey")
    create(:ingredient, name: "cooking spray", optional: true)
    create(:recipe, title: "E2E Honey Toast", ingredient_names: [ "honey", "cooking spray", "bread" ])

    visit recipes_path

    page.execute_script(<<~JS)
      document.cookie = `pennylunch.ingredients=${encodeURIComponent(JSON.stringify({ selected: ["honey", "cooking spray"], enabled: false }))}; Path=/; SameSite=Lax`;
      window.dispatchEvent(new CustomEvent("pennylunch:ingredient-basket-change"));
    JS

    expect(page).to have_no_css(".recipe-card-ingredients .recipe-ingredient-match", text: "honey")
    expect(page).to have_no_css(".recipe-card-ingredients .recipe-ingredient-match", text: "cooking spray")

    page.execute_script(<<~JS)
      document.querySelector("[data-auto-submit-target~='ingredients']").value = "honey";
      document.cookie = `pennylunch.ingredients=${encodeURIComponent(JSON.stringify({ selected: ["honey", "cooking spray"], enabled: true }))}; Path=/; SameSite=Lax`;
      window.dispatchEvent(new CustomEvent("pennylunch:ingredient-basket-change"));
    JS

    expect(page).to have_css(".recipe-card-ingredients .recipe-ingredient-match", text: "honey")
    expect(page).to have_css(".recipe-card-ingredients .recipe-ingredient-match", text: "cooking spray")
  end

  it "wraps the readiness tooltip instead of clipping the explanation" do
    eggs = create(:ingredient, name: "eggs")
    milk = create(:ingredient, name: "milk")
    flour = create(:ingredient, name: "all-purpose flour")
    recipe = create(:recipe, title: "E2E Tooltip Pancakes", ingredient_names: [ "eggs", "milk", "all-purpose flour" ])
    [ eggs, milk, flour ].each { |ingredient| create(:recipe_ingredient, recipe:, ingredient:) }

    visit recipes_path(ingredients: [ "eggs", "milk" ])

    find(".recipe-card", text: "E2E Tooltip Pancakes").find(".recipe-match-readiness").hover

    tooltip = page.evaluate_script(<<~JS)
      (() => {
        const card = Array.from(document.querySelectorAll(".recipe-card")).find((element) => element.textContent.includes("E2E Tooltip Pancakes"));
        const readiness = card.querySelector(".recipe-match-readiness");
        const style = getComputedStyle(readiness, "::before");
        const readinessRect = readiness.getBoundingClientRect();
        const tooltipWidth = Number.parseFloat(style.width);

        return {
          content: style.content,
          left: Math.round(readinessRect.right - tooltipWidth),
          overflow: style.overflow,
          textOverflow: style.textOverflow,
          visibility: style.visibility,
          whiteSpace: style.whiteSpace,
          width: Math.round(tooltipWidth),
          viewportWidth: window.innerWidth
        };
      })()
    JS

    expect(tooltip.fetch("content")).to include("Pantry staples are not counted.")
    expect(tooltip.fetch("visibility")).to eq("visible")
    expect(tooltip.fetch("whiteSpace")).to eq("normal")
    expect(tooltip.fetch("overflow")).to eq("visible")
    expect(tooltip.fetch("textOverflow")).to eq("clip")
    expect(tooltip.fetch("left")).to be >= 0
    expect(tooltip.fetch("width")).to be <= tooltip.fetch("viewportWidth") - 32
  end

  it "renders the basket panel with a bottom autocomplete input and no add button" do
    visit recipes_path

    find("[data-ingredients-fab-target='trigger']").click
    find("#recipe-ingredients-input").click
    page.driver.browser.execute_async_script("const done = arguments[arguments.length - 1]; setTimeout(done, 220);")

    expect(page).to have_no_css("[data-ingredients-fab-target='addButton']")
    expect(page).to have_no_text("Add Ingredient")

    layout = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector("#recipe-ingredients-panel").getBoundingClientRect();
        const picker = document.querySelector(".recipe-ingredients-picker");
        const pickerRect = picker.getBoundingClientRect();
        const selected = document.querySelector(".recipe-ingredients-selected").getBoundingClientRect();
        const emptyState = document.querySelector(".recipe-ingredients-empty-state").getBoundingClientRect();
        const emptyStatePhrase = document.querySelector(".recipe-ingredients-empty-state-phrase").getBoundingClientRect();
        const emptyStateMark = getComputedStyle(document.querySelector(".recipe-ingredients-empty-state"), "::before");
        const input = document.querySelector("#recipe-ingredients-input");
        const photoTrigger = document.querySelector(".recipe-ingredients-photo-trigger");
        const inputGroup = document.querySelector(".recipe-ingredients-input-group").getBoundingClientRect();
        const inputGroupStyle = getComputedStyle(document.querySelector(".recipe-ingredients-input-group"));
        const inputStyle = getComputedStyle(input);
        const photoTriggerStyle = getComputedStyle(photoTrigger);
        const pickerStyle = getComputedStyle(picker);
        const paddingBottom = Number.parseFloat(getComputedStyle(picker).paddingBottom);
        const gap = Number.parseFloat(pickerStyle.rowGap || pickerStyle.gap);

        return {
          activeId: document.activeElement.id,
          inputBoxShadow: inputStyle.boxShadow,
          inputBorderColor: inputStyle.borderTopColor,
          inputGroupTopLeftRadius: inputGroupStyle.borderTopLeftRadius,
          inputGroupBottomLeftRadius: inputGroupStyle.borderBottomLeftRadius,
          inputGroupTopRightRadius: inputGroupStyle.borderTopRightRadius,
          inputGroupBottomRightRadius: inputGroupStyle.borderBottomRightRadius,
          inputTopLeftRadius: inputStyle.borderTopLeftRadius,
          inputBottomLeftRadius: inputStyle.borderBottomLeftRadius,
          inputGroupBoxShadow: inputGroupStyle.boxShadow,
          photoTriggerBorderTopColor: photoTriggerStyle.borderTopColor,
          photoTriggerBorderRightColor: photoTriggerStyle.borderRightColor,
          photoTriggerBorderBottomColor: photoTriggerStyle.borderBottomColor,
          photoTriggerTopRightRadius: photoTriggerStyle.borderTopRightRadius,
          photoTriggerBottomRightRadius: photoTriggerStyle.borderBottomRightRadius,
          inputBottomGap: Math.round(panel.bottom - inputGroup.bottom - paddingBottom),
          selectedTopGap: Math.round(selected.top - pickerRect.top),
          selectedInputGap: Math.round(inputGroup.top - selected.bottom - gap),
          selectedHeight: Math.round(selected.height),
          emptyStateBackground: emptyStateMark.backgroundImage,
          emptyStatePhraseBelowCenter: emptyStatePhrase.top > (emptyState.top + emptyState.height / 2),
          emptyStatePhraseLeftGap: Math.round(emptyStatePhrase.left - selected.left),
          emptyStatePhraseRightGap: Math.round(selected.right - emptyStatePhrase.right)
        };
      })()
    JS

    expect(layout.fetch("activeId")).to eq("recipe-ingredients-input")
    expect(layout.fetch("inputBoxShadow")).to eq("none")
    expect(layout.fetch("inputGroupBoxShadow")).not_to eq("none")
    expect(layout.fetch("inputTopLeftRadius")).to eq(layout.fetch("inputGroupTopLeftRadius"))
    expect(layout.fetch("inputBottomLeftRadius")).to eq(layout.fetch("inputGroupBottomLeftRadius"))
    expect(layout.fetch("photoTriggerTopRightRadius")).to eq(layout.fetch("inputGroupTopRightRadius"))
    expect(layout.fetch("photoTriggerBottomRightRadius")).to eq(layout.fetch("inputGroupBottomRightRadius"))
    expect(layout.fetch("photoTriggerBorderTopColor")).to eq(layout.fetch("inputBorderColor"))
    expect(layout.fetch("photoTriggerBorderRightColor")).to eq(layout.fetch("inputBorderColor"))
    expect(layout.fetch("photoTriggerBorderBottomColor")).to eq(layout.fetch("inputBorderColor"))
    expect(layout.fetch("inputBottomGap").abs).to be <= 2
    expect(layout.fetch("selectedTopGap").abs).to be <= 2
    expect(layout.fetch("selectedInputGap").abs).to be <= 2
    expect(layout.fetch("selectedHeight")).to be_positive
    expect(layout.fetch("emptyStateBackground")).to include("/icon-512x512.png")
    expect(layout.fetch("emptyStatePhraseBelowCenter")).to be(true)
    expect(layout.fetch("emptyStatePhraseLeftGap")).to be >= 16
    expect(layout.fetch("emptyStatePhraseRightGap")).to be >= 16
  end

  it "keeps the basket panel open after adding an ingredient while filtering is enabled" do
    honey = create(:ingredient, name: "honey")
    matching_recipe = create(:recipe, title: "E2E Honey Toast", ingredient_names: [ "honey" ])
    create(:recipe_ingredient, recipe: matching_recipe, ingredient: honey)

    visit recipes_path

    find("[data-ingredients-fab-target='trigger']").click
    find(".recipe-ingredients-switch").click
    expect(page).to have_text("only matching recipes are displayed.")

    find("#recipe-ingredients-input").set("hon")
    expect(page).to have_css(".recipe-ingredients-option", text: "honey")
    find("#recipe-ingredients-input").send_keys(:enter)
    page.driver.browser.execute_async_script("const done = arguments[arguments.length - 1]; setTimeout(done, 400);")

    expect(Rack::Utils.parse_nested_query(URI.parse(page.current_url).query)).to include("ingredients" => [ "honey" ])
    expect(page).to have_css("#recipe-ingredients-panel:not([hidden])")
    expect(page).to have_css(".recipe-ingredients-row", text: "honey")
    expect(page).to have_text("only matching recipes are displayed.")
    expect(page).to have_no_text("Add what is in your kitchen.")

    empty_state = page.evaluate_script(<<~JS)
      (() => {
        const emptyState = document.querySelector(".recipe-ingredients-empty-state");
        const phrase = document.querySelector(".recipe-ingredients-empty-state-phrase");
        const mark = getComputedStyle(emptyState, "::before");

        return {
          stateDisplay: getComputedStyle(emptyState).display,
          phraseDisplay: getComputedStyle(phrase).display,
          markImage: mark.backgroundImage
        };
      })()
    JS

    expect(empty_state.fetch("stateDisplay")).not_to eq("none")
    expect(empty_state.fetch("phraseDisplay")).to eq("none")
    expect(empty_state.fetch("markImage")).to include("/icon-512x512.png")
  end

  it "adds a show-page ingredient to the basket from the row action" do
    create(:ingredient, name: "honey")
    recipe = create(
      :recipe,
      title: "E2E Honey Detail",
      ingredients: [ "1 teaspoon honey" ],
      ingredient_names: [ "honey" ],
      ingredient_parse_data: [
        {
          "parser" => {
            "amount" => [ { "quantity" => "1", "unit" => "teaspoon" } ],
            "name" => [ { "text" => "honey" } ]
          }
        }
      ]
    )

    visit recipe_path(recipe)

    within(".recipe-ingredient-row", text: "honey") do
      expect(page).to have_button("I have it")
      click_button "I have it"
    end

    expect(page).to have_css(".recipe-ingredient-row--matched", text: "honey")
    expect(page).to have_no_css(".recipe-ingredient-row .recipe-ingredient-basket-button", text: "I have it")

    find("[data-ingredients-fab-target='trigger']").click
    expect(page).to have_css(".recipe-ingredients-row", text: "honey")

    basket = page.evaluate_script(<<~JS)
      (() => {
        const value = document.cookie.split(";").map((item) => item.trim()).find((item) => item.startsWith("pennylunch.ingredients="));
        return JSON.parse(decodeURIComponent(value.split("=")[1]));
      })()
    JS

    expect(basket.fetch("selected")).to include("honey")
    expect(basket.fetch("enabled")).to be(false)

    within(".recipe-ingredient-row", text: "honey") do
      expect(page).to have_css("button.recipe-ingredient-match-icon[aria-label='Remove honey from basket']:not(:disabled)")
      find("button.recipe-ingredient-match-icon[aria-label='Remove honey from basket']").click
      expect(page).to have_button("I have it")
    end

    expect(page).to have_no_css(".recipe-ingredient-row--matched", text: "honey")

    basket = page.evaluate_script(<<~JS)
      (() => {
        const value = document.cookie.split(";").map((item) => item.trim()).find((item) => item.startsWith("pennylunch.ingredients="));
        return JSON.parse(decodeURIComponent(value.split("=")[1]));
      })()
    JS

    expect(basket.fetch("selected")).not_to include("honey")
    expect(basket.fetch("enabled")).to be(false)
  end

  it "fills the basket from a pasted image URL reader response" do
    create(:ingredient, name: "honey")

    visit recipes_path

    page.execute_script(<<~JS)
      window.fetch = async (url, options) => {
        const body = options.body;
        window.__imageReaderRequest = {
          url: url.toString(),
          method: options.method,
          imageUrl: body.get("image[url]"),
          fileName: body.get("image[file]")?.name || null
        };

        return new Promise((resolve) => {
          window.__resolveImageReader = () => resolve(new Response(JSON.stringify({ ingredients: ["honey"] }), {
            status: 200,
            headers: { "Content-Type": "application/json" }
          }));
        });
      };
    JS

    find("[data-ingredients-fab-target='trigger']").click
    find("button[aria-label='Scan photo or image URL']").click

    expect(page).to have_css("#recipe-ingredients-image-dialog[open]")
    expect(page).to have_text("Pen can fill your basket from a photo.")
    expect(page).to have_text("Drop a photo here")
    expect(page).to have_no_button("Read image")

    dialog_layout = page.evaluate_script(<<~JS)
      (() => {
        const dialog = document.querySelector("#recipe-ingredients-image-dialog");
        const form = dialog.querySelector(".recipe-ingredients-image-form");
        const urlInput = dialog.querySelector("input[name='image[url]']");
        const dropzone = dialog.querySelector(".recipe-ingredients-image-dropzone");
        const dialogRect = dialog.getBoundingClientRect();
        const formRect = form.getBoundingClientRect();
        const inputRect = urlInput.getBoundingClientRect();
        const dropzoneRect = dropzone.getBoundingClientRect();
        const dropzoneStyle = getComputedStyle(dropzone);

        return {
          viewportWidth: window.innerWidth,
          viewportHeight: window.innerHeight,
          dialogLeft: Math.round(dialogRect.left),
          dialogRight: Math.round(dialogRect.right),
          dialogTop: Math.round(dialogRect.top),
          dialogBottom: Math.round(dialogRect.bottom),
          dialogWidth: Math.round(dialogRect.width),
          formWidth: Math.round(formRect.width),
          dropzoneHeight: Math.round(dropzoneRect.height),
          dropzoneWidth: Math.round(dropzoneRect.width),
          dropzoneBorderStyle: dropzoneStyle.borderTopStyle,
          inputLeft: Math.round(inputRect.left),
          inputRight: Math.round(inputRect.right)
        };
      })()
    JS

    expect(dialog_layout.fetch("dialogLeft")).to be >= 16
    expect(dialog_layout.fetch("dialogTop")).to be >= 16
    expect(dialog_layout.fetch("dialogRight")).to be <= dialog_layout.fetch("viewportWidth") - 16
    expect(dialog_layout.fetch("dialogBottom")).to be <= dialog_layout.fetch("viewportHeight") - 16
    expect(dialog_layout.fetch("dialogWidth")).to be <= 480
    expect(dialog_layout.fetch("formWidth")).to be <= dialog_layout.fetch("dialogWidth")
    expect(dialog_layout.fetch("formWidth")).to be >= dialog_layout.fetch("dialogWidth") - 4
    expect((dialog_layout.fetch("dropzoneHeight") - dialog_layout.fetch("dropzoneWidth")).abs).to be <= 2
    expect(dialog_layout.fetch("dropzoneBorderStyle")).to eq("dashed")
    expect(dialog_layout.fetch("inputLeft")).to be >= dialog_layout.fetch("dialogLeft")
    expect(dialog_layout.fetch("inputRight")).to be <= dialog_layout.fetch("dialogRight")

    fill_in "Image URL", with: "https://example.com/pantry.jpg"
    page.execute_script(<<~JS)
      document.querySelector("input[name='image[url]']").dispatchEvent(new Event("paste", { bubbles: true, cancelable: true }));
    JS

    expect(page).to have_css("#recipe-ingredients-image-dialog[data-state='loading']")
    expect(page).to have_css(".recipe-ingredients-image-thinking", text: "Reading your photo...")
    expect(page).to have_css(".recipe-ingredients-image-idle[hidden]", visible: :all)

    loading_state = page.evaluate_script(<<~JS)
      (() => {
        const dialog = document.querySelector("#recipe-ingredients-image-dialog");
        const header = dialog.querySelector(".recipe-ingredients-image-header");
        const spinner = dialog.querySelector(".recipe-ingredients-image-spinner");
        const star = dialog.querySelector(".recipe-ingredients-image-star");

        return {
          state: dialog.dataset.state,
          headerDisplay: getComputedStyle(header).display,
          spinnerAnimationName: getComputedStyle(spinner).animationName,
          starAnimationName: getComputedStyle(star).animationName
        };
      })()
    JS

    expect(loading_state.fetch("state")).to eq("loading")
    expect(loading_state.fetch("headerDisplay")).to eq("none")
    expect(loading_state.fetch("spinnerAnimationName")).to eq("recipe-ingredients-image-spin")
    expect(loading_state.fetch("starAnimationName")).to eq("recipe-ingredients-image-star")

    page.execute_script("window.__resolveImageReader()")

    expect(page).to have_no_css("#recipe-ingredients-image-dialog[open]")
    expect(page).to have_css("#recipe-ingredients-panel:not([hidden])")
    expect(page).to have_css(".recipe-ingredients-row", text: "honey")

    request = page.evaluate_script("window.__imageReaderRequest")
    basket = page.evaluate_script(<<~JS)
      (() => {
        const value = document.cookie.split(";").map((item) => item.trim()).find((item) => item.startsWith("pennylunch.ingredients="));
        return JSON.parse(decodeURIComponent(value.split("=")[1]));
      })()
    JS

    expect(request).to include(
      "url" => "http://127.0.0.1:#{Capybara.current_session.server.port}/ingredient_image",
      "method" => "POST",
      "imageUrl" => "https://example.com/pantry.jpg",
      "fileName" => nil
    )
    expect(basket.fetch("selected")).to include("honey")
  end

  it "fills the basket from a dropped image file reader response" do
    create(:ingredient, name: "honey")

    visit recipes_path

    page.execute_script(<<~JS)
      window.fetch = (url, options) => {
        const body = options.body;
        window.__imageReaderRequest = {
          url: url.toString(),
          method: options.method,
          imageUrl: body.get("image[url]"),
          fileName: body.get("image[file]")?.name || null
        };

        return new Promise((resolve) => {
          window.__resolveImageReader = () => resolve(new Response(JSON.stringify({ ingredients: ["honey"] }), {
            status: 200,
            headers: { "Content-Type": "application/json" }
          }));
        });
      };
    JS

    find("[data-ingredients-fab-target='trigger']").click
    find("button[aria-label='Scan photo or image URL']").click

    page.execute_script(<<~JS)
      const dropzone = document.querySelector(".recipe-ingredients-image-dropzone");
      const file = new File(["image-bytes"], "basket.png", { type: "image/png" });
      const transfer = new DataTransfer();
      transfer.items.add(file);
      dropzone.dispatchEvent(new DragEvent("drop", { bubbles: true, cancelable: true, dataTransfer: transfer }));
    JS

    expect(page).to have_css("#recipe-ingredients-image-dialog[data-state='loading']")
    expect(page).to have_css(".recipe-ingredients-image-thinking", text: "Reading your photo...")

    page.execute_script("window.__resolveImageReader()")

    expect(page).to have_no_css("#recipe-ingredients-image-dialog[open]")
    expect(page).to have_css(".recipe-ingredients-row", text: "honey")

    request = page.evaluate_script("window.__imageReaderRequest")
    basket = page.evaluate_script(<<~JS)
      (() => {
        const value = document.cookie.split(";").map((item) => item.trim()).find((item) => item.startsWith("pennylunch.ingredients="));
        return JSON.parse(decodeURIComponent(value.split("=")[1]));
      })()
    JS

    expect(request).to include(
      "url" => "http://127.0.0.1:#{Capybara.current_session.server.port}/ingredient_image",
      "method" => "POST",
      "imageUrl" => nil,
      "fileName" => "basket.png"
    )
    expect(basket.fetch("selected")).to include("honey")
  end

  it "does not resubmit ingredient filters after returning from a show page" do
    honey = create(:ingredient, name: "honey")
    matching_recipe = create(:recipe, title: "E2E Cookie Basket Honey Toast", ingredient_names: [ "honey" ])
    create(:recipe, title: "E2E Cookie Basket Apple Cake", ingredient_names: [ "apple" ])
    create(:recipe_ingredient, recipe: matching_recipe, ingredient: honey)

    visit recipe_path(matching_recipe)

    page.execute_script(<<~JS)
      window.__pennylunchFetches = [];
      document.addEventListener("turbo:before-fetch-request", (event) => {
        window.__pennylunchFetches.push(event.detail.url.toString());
      });
      document.cookie = `pennylunch.ingredients=${encodeURIComponent(JSON.stringify({ selected: ["honey"], enabled: true }))}; Path=/; SameSite=Lax`;
      window.dispatchEvent(new CustomEvent("pennylunch:ingredient-basket-change"));
    JS

    click_link "PennyLunch"

    expect(page).to have_current_path("/recipes")
    expect(page).to have_text("E2E Cookie Basket Honey Toast")
    expect(page).to have_no_text("E2E Cookie Basket Apple Cake")

    page.driver.browser.execute_async_script("const done = arguments[arguments.length - 1]; setTimeout(done, 300);")

    expect(page.evaluate_script("window.__pennylunchFetches").count).to eq(1)
  end

  def clear_browser_basket
    page.driver.browser.manage.delete_all_cookies
    page.execute_script("window.localStorage.clear()") if page.current_url.start_with?("http")
  end
end
