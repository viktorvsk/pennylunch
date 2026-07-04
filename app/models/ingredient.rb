class Ingredient < ApplicationRecord
  has_many :recipe_ingredients, dependent: :delete_all

  normalizes :name, with: ->(name) { name.to_s.squish.downcase.presence }
  normalizes :aliases, with: ->(aliases) { aliases.is_a?(Array) ? aliases.filter_map { it.to_s.squish.downcase.presence }.uniq : aliases }

  validates :name, presence: true, uniqueness: true
  validates :name, format: { without: /,/, message: "must not contain commas" }
  validate :aliases_must_be_array
  validate :aliases_must_be_present
  validate :aliases_must_be_globally_unique
  validate :name_must_not_match_another_alias

  after_commit :clear_cache

  class << self
    def filterable_matches(text)
      names = Array(text).filter_map { it.to_s.squish.presence }.uniq
      return [] if names.empty?

      by_name = where(optional: false, name: names).index_by(&:name)
      names.filter_map { by_name[it] }
    end
  end

  private

  def clear_cache
    Rails.cache.delete(IngredientCatalogMetadata::CACHE_KEY)
    Rails.cache.delete("ingredients/filterable_lookup_map")
  end

  def aliases_must_be_array
    errors.add(:aliases, "must be an array") unless aliases.is_a?(Array)
  end

  def aliases_must_be_present
    errors.add(:aliases, "must have at least one alias") if aliases.is_a?(Array) && aliases.empty?
  end

  def aliases_must_be_globally_unique
    return unless aliases.is_a?(Array) && aliases.any?

    others = self.class.where.not(id:)
    # pg array syntax for jsonb_exists_any
    if others.where("jsonb_exists_any(aliases, ARRAY[?]::text[])", aliases).exists?
      errors.add(:aliases, "must be unique across ingredients")
    end

    if others.where(name: aliases).exists?
      errors.add(:aliases, "must not match another ingredient name")
    end
  end

  def name_must_not_match_another_alias
    return if name.blank?

    others = self.class.where.not(id:)
    if others.where("jsonb_exists(aliases, ?)", name).exists?
      errors.add(:name, "must not match another ingredient alias")
    end
  end
end
