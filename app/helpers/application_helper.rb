module ApplicationHelper
  DEFAULT_ICON_SIZE = "size-4"
  DEFAULT_INGREDIENT_SUMMARY_LIMIT = 8
  MAX_RATING_STARS = 5
  RATING_PRECISION = 2
  RECIPE_UI_CATALOG_CACHE_EXPIRATION = 5.minutes
  RECIPE_UI_CATALOG_CACHE_KEY = "recipes/ui_catalog/v1"
  SORT_OPTIONS = {
    "time_asc" => "Time ascending",
    "time_desc" => "Time descending",
    "rating_asc" => "Rating ascending",
    "rating_desc" => "Rating descending"
  }.freeze

  def filled_stars(rating)
    filled_count = rating.to_f.round.clamp(0, MAX_RATING_STARS)
    safe_join(MAX_RATING_STARS.times.map do |index|
      content_tag(:span, "★", class: index < filled_count ? "text-amber-500" : "text-zinc-300")
    end)
  end

  def rating_stars(rating, **options)
    class_name = options.fetch(:class_name, "recipe-rating")
    side = options.fetch(:side, "bottom")
    align = options.fetch(:align, "end")
    value = number_with_precision(rating, precision: RATING_PRECISION)
    content_tag(
      :span,
      filled_stars(rating),
      class: class_name,
      aria: { label: "Rating #{value} out of 5" },
      data: { tooltip: "Rating: #{value} out of 5", side:, align: }
    )
  end

  def category_label(recipe)
    recipe.category.presence || "Uncategorized"
  end

  def recipe_ingredient_names(recipe)
    Array(recipe.ingredient_names).filter_map { |name| name.to_s.squish.presence }
  end

  def ingredient_name_summary(recipe, limit: DEFAULT_INGREDIENT_SUMMARY_LIMIT)
    names = recipe_ingredient_names(recipe)
    return "" if names.empty?

    visible_names = names.first(limit)
    remaining_count = names.size - visible_names.size
    suffix = remaining_count.positive? ? " + #{remaining_count} more" : ""
    "#{visible_names.join(", ")}#{suffix}"
  end

  def recipe_time_tooltip(recipe)
    result = []
    result << "prepare for #{recipe.prep_time} minutes" unless recipe.prep_time.zero?
    result << "then" if recipe.prep_time.positive? and recipe.cook_time.positive?
    result << "cook for #{recipe.cook_time} minutes" unless recipe.cook_time.zero?
    result.join(" ").capitalize
  end

  def recipe_ingredient_rows(recipe)
    Array(recipe.ingredients).each_with_index.map do |ingredient, index|
      parser = ingredient_parser_payload(recipe, index)
      amount = Array(parser["amount"]).find { |value| value.is_a?(Hash) } || {}
      name = Array(parser["name"]).find { |value| value.is_a?(Hash) } || {}
      state = [ parser["preparation"], parser["comment"], parser["purpose"], parser["size"] ].filter_map { |value| ingredient_parser_value(value) }.join(", ")

      {
        size: amount["quantity"].presence || amount["quantity_max"].presence || amount["text"].presence,
        unit: amount["unit"].presence,
        name: name["text"].presence || Array(recipe.ingredient_names)[index].presence || ingredient.to_s,
        state:
      }
    end
  end

  def ingredient_reference_url(name)
    "https://en.wikipedia.org/wiki/#{ERB::Util.url_encode(name.to_s.squish.tr(" ", "_"))}"
  end

  def category_heading(category)
    category.to_s.titleize
  end

  def recipe_sort_options
    SORT_OPTIONS
  end

  def recipe_sort_label(sort)
    SORT_OPTIONS.fetch(sort.presence || Recipes::SortQuery::DEFAULT_SORT, SORT_OPTIONS.fetch(Recipes::SortQuery::DEFAULT_SORT))
  end

  def recipe_ui_catalog
    Rails.cache.fetch(RECIPE_UI_CATALOG_CACHE_KEY, expires_in: RECIPE_UI_CATALOG_CACHE_EXPIRATION) do
      category_labels = Recipes::CategoryCatalogQuery.labels

      {
        ingredient_options: Ingredient.filter_options,
        category_labels:,
        category_slugs: category_labels.keys.to_h { |category| [ category, Recipe.category_slug_for(category) ] }
      }
    end
  end

  def recipe_ui_catalog_json
    catalog = recipe_ui_catalog
    {
      ingredientOptions: catalog.fetch(:ingredient_options),
      categoryLabels: catalog.fetch(:category_labels),
      categorySlugs: catalog.fetch(:category_slugs)
    }.to_json
  end

  def recipe_category_labels
    recipe_ui_catalog.fetch(:category_labels)
  end

  def recipe_category_from_slug(slug)
    recipe_ui_catalog.fetch(:category_slugs).key(slug.to_s)
  end

  def recipe_layout_fab_filters
    params.slice(:ingredients).permit(:ingredients).to_h
  end

  def recipe_filter_path(filters = {})
    values = filters.to_h.with_indifferent_access
    category = Recipe.normalize_category(values.delete(:category))
    values.delete(:page) if values[:page].blank?
    values.delete(:sort) if values[:sort].blank? || values[:sort] == Recipes::SortQuery::DEFAULT_SORT
    values.compact_blank!

    path = category.present? ? "/recipes/#{Recipe.category_slug_for(category)}" : recipes_path
    values.present? ? "#{path}?#{values.to_query}" : path
  end

  def icon_svg(name, class_name: DEFAULT_ICON_SIZE)
    paths = {
      category: [
        tag.path(d: "M4 4h6v6H4z"),
        tag.path(d: "M14 4h6v6h-6z"),
        tag.path(d: "M4 14h6v6H4z"),
        tag.path(d: "M14 14h6v6h-6z")
      ],
      check: [
        tag.path(d: "M20 6 9 17l-5-5")
      ],
      clock: [
        tag.circle(cx: "12", cy: "12", r: "10"),
        tag.path(d: "M12 6v6l4 2")
      ],
      ingredients: [
        tag.path(d: "M2 11h20"),
        tag.path(d: "m5 11 4-7"),
        tag.path(d: "m15 4 4 7"),
        tag.path(d: "m3.5 11 1.6 7.4A2 2 0 0 0 7 20h10a2 2 0 0 0 1.9-1.6l1.6-7.4"),
        tag.path(d: "M4.5 15.5h15"),
        tag.path(d: "m9 11 1 9"),
        tag.path(d: "m15 11-1 9")
      ],
      popular: [
        tag.path(d: "M12 3.5 14.7 9l6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1L3.2 9l6.1-.9L12 3.5Z")
      ],
      quick: [
        tag.path(d: "M13 2 4 14h7l-1 8 9-12h-7l1-8Z")
      ],
      settings: [
        tag.circle(cx: "12", cy: "12", r: "3"),
        tag.path(d: "M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3 1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8 1.7 1.7 0 0 0 1.5 1h.1a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.3 1Z")
      ],
      sad_face: [
        tag.circle(cx: "12", cy: "12", r: "10"),
        tag.path(d: "M8 9h.01"),
        tag.path(d: "M16 9h.01"),
        tag.path(d: "M8 16a5 5 0 0 1 8 0")
      ],
      sort: [
        tag.path(d: "M7 6h10"),
        tag.path(d: "M7 12h7"),
        tag.path(d: "M7 18h4"),
        tag.path(d: "m17 15 3 3 3-3"),
        tag.path(d: "M20 6v12")
      ],
      user: [
        tag.path(d: "M20 21a8 8 0 0 0-16 0"),
        tag.circle(cx: "12", cy: "7", r: "4")
      ]
    }

    tag.svg(
      safe_join(paths.fetch(name)),
      class: class_name,
      aria: { hidden: true },
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      stroke_width: "2",
      stroke_linecap: "round",
      stroke_linejoin: "round",
    )
  end

  def ingredient_parser_payload(recipe, index)
    item = Array(recipe.ingredient_parse_data)[index]
    item.is_a?(Hash) && item["parser"].is_a?(Hash) ? item["parser"] : {}
  end

  def ingredient_parser_value(value)
    case value
    when Array
      value.filter_map { |item| ingredient_parser_value(item) }.join(", ").presence
    when Hash
      value["text"].presence || value["name"].presence || value.values.filter_map { |item| ingredient_parser_value(item) }.join(", ").presence
    else
      value.to_s.squish.presence
    end
  end
end
