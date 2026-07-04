class Ingredient < ApplicationRecord
  before_validation :normalize_name
  before_validation :normalize_aliases

  validates :name, presence: true, uniqueness: true
  validate :aliases_must_be_array
  validate :aliases_must_be_present
  validate :aliases_must_be_globally_unique
  validate :name_must_not_match_another_alias
  validate :name_must_be_canonical

  def self.normalize_lookup_key(value)
    value.to_s.squish.downcase.presence
  end

  def self.filterable_lookup_map
    where(optional: false).pluck(:name, :aliases).each_with_object({}) do |(name, aliases), mapping|
      ([ name ] + Array(aliases)).each do |value|
        key = normalize_lookup_key(value)
        mapping[key] = name if key.present?
      end
    end
  end

  def self.filterable_canonical_names_for(names)
    mapping = filterable_lookup_map
    Array(names).filter_map { |name| mapping[normalize_lookup_key(name)] }.uniq
  end

  def self.filter_options
    order(:name).pluck(:name, :optional).map { |name, optional| { name:, optional: } }
  end

  private

  def normalize_name
    self.name = self.class.normalize_lookup_key(name) if name.present?
  end

  def normalize_aliases
    self.aliases = [] if aliases.nil?
    return unless aliases.is_a?(Array)

    self.aliases = aliases.filter_map { |value| value.to_s.squish.downcase.presence }.uniq
  end

  def aliases_must_be_array
    errors.add(:aliases, "must be an array") unless aliases.is_a?(Array)
  end

  def aliases_must_be_present
    errors.add(:aliases, "must have at least one alias") if aliases.is_a?(Array) && aliases.empty?
  end

  def aliases_must_be_globally_unique
    return unless aliases.is_a?(Array) && aliases.any?

    normalized_aliases = aliases.filter_map { |alias_name| self.class.normalize_lookup_key(alias_name) }
    other_ingredients = self.class.where.not(id:).pluck(:name, :aliases)

    if other_ingredients.any? { |_other_name, other_aliases| (Array(other_aliases).filter_map { |alias_name| self.class.normalize_lookup_key(alias_name) } & normalized_aliases).any? }
      errors.add(:aliases, "must be unique across ingredients")
    end

    if other_ingredients.any? { |other_name, _other_aliases| normalized_aliases.include?(self.class.normalize_lookup_key(other_name)) }
      errors.add(:aliases, "must not match another ingredient name")
    end
  end

  def name_must_not_match_another_alias
    return if name.blank?

    normalized_name = self.class.normalize_lookup_key(name)
    exists = self.class.where.not(id:).pluck(:aliases).any? do |other_aliases|
      Array(other_aliases).filter_map { |alias_name| self.class.normalize_lookup_key(alias_name) }.include?(normalized_name)
    end
    errors.add(:name, "must not match another ingredient alias") if exists
  end

  def name_must_be_canonical
    errors.add(:name, "must not contain commas") if name.to_s.include?(",")
  end
end
