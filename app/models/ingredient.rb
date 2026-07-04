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

  class << self
    def normalize_lookup_key(value)
      value.to_s.squish.downcase.presence
    end

    def normalize_lookup_keys(values)
      Array(values).filter_map { normalize_lookup_key(it) }.uniq
    end

    def lookup_map(scope = all)
      scope.pluck(:name, :aliases).each_with_object({}) do |(name, aliases), mapping|
        ([ name ] + aliases).each do |value|
          key = normalize_lookup_key(value)
          mapping[key] = name if key.present?
        end
      end
    end

    def filterable_lookup_map
      lookup_map(where(optional: false))
    end

    def filter_options
      order(:name).pluck(:name, :optional).map { |name, optional| { name:, optional: } }
    end

    def filterable_matches(text)
      names = text.to_s.split(/[\n,;]+/).filter_map { normalize_lookup_key(it) }.uniq
      return [] if names.empty?

      where(optional: false, name: names).to_a
    end

    def catalog_metadata
      pluck(:name, :aliases, :optional).each_with_object({}) do |(name, aliases, optional), mapping|
        ([ name ] + aliases).each do |value|
          key = normalize_lookup_key(value)
          mapping[key] = { name:, optional: } if key.present?
        end
      end
    end
  end

  private

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
