module ApplicationHelper
  def filled_stars(rating)
    filled_count = rating.to_f.round.clamp(0, 5)
    safe_join(5.times.map do |index|
      content_tag(:span, "★", class: index < filled_count ? "text-amber-500" : "text-zinc-300")
    end)
  end

  def rating_stars(rating, class_name: "shrink-0 text-sm")
    value = number_with_precision(rating, precision: 2)
    content_tag(:span, filled_stars(rating), class: class_name, aria: { label: "#{value} out of 5" }, title: "#{value} out of 5")
  end

  def category_label(recipe)
    recipe.category.presence || "Uncategorized"
  end
end
