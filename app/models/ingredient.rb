class Ingredient < ApplicationRecord
  LOOKUP_WORD_INFLECTIONS = {
    "berries" => "berry",
    "blueberries" => "blueberry",
    "cherries" => "cherry",
    "cranberries" => "cranberry",
    "raspberries" => "raspberry",
    "strawberries" => "strawberry",
    "zucchinis" => "zucchini"
  }.freeze

  before_validation :normalize_name
  before_validation :normalize_aliases

  validates :name, presence: true, uniqueness: true
  validate :aliases_must_be_array
  validate :aliases_must_be_present
  validate :aliases_must_be_globally_unique
  validate :name_must_not_match_another_alias
  validate :name_must_be_canonical

  def self.normalize_lookup_key(value)
    value.to_s.squish.downcase.split.filter_map { |word| normalize_lookup_word(word).presence }.join(" ").presence
  end

  def self.lookup_map
    lookup_map_for(all)
  end

  def self.filterable_lookup_map
    lookup_map_for(where(optional: false))
  end

  def self.lookup_map_for(scope)
    scope.pluck(:name, :aliases).each_with_object({}) do |(name, aliases), mapping|
      ([ name ] + Array(aliases)).each do |value|
        key = normalize_lookup_key(value)
        mapping[key] = name if key.present?
      end
    end
  end
  private_class_method :lookup_map_for

  def self.canonical_names_for(names)
    canonical_names_for_lookup(names, lookup_map)
  end

  def self.filterable_canonical_names_for(names)
    canonical_names_for_lookup(names, filterable_lookup_map)
  end

  def self.canonical_names_for_lookup(names, mapping)
    Array(names).filter_map { |name| mapping[normalize_lookup_key(name)] }.uniq
  end
  private_class_method :canonical_names_for_lookup

  def self.filter_options
    order(:name).pluck(:name, :optional).map { |name, optional| { name:, optional: } }
  end

  def self.normalize_lookup_word(word)
    return LOOKUP_WORD_INFLECTIONS.fetch(word) if LOOKUP_WORD_INFLECTIONS.key?(word)

    case word
    when /oes\z/
      word.delete_suffix("es")
    when /s\z/
      word.match?(/(?:ss|us)\z/) ? word : word.delete_suffix("s")
    else
      word
    end
  end
  private_class_method :normalize_lookup_word

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
