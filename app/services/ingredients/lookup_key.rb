module Ingredients
  class LookupKey
    WORD_INFLECTIONS = {
      "berries" => "berry",
      "blueberries" => "blueberry",
      "cherries" => "cherry",
      "cranberries" => "cranberry",
      "raspberries" => "raspberry",
      "strawberries" => "strawberry",
      "zucchinis" => "zucchini"
    }.freeze

    def self.normalize(value)
      value.to_s.squish.downcase.split.filter_map { |word| normalize_word(word).presence }.join(" ").presence
    end

    def self.normalize_word(word)
      return WORD_INFLECTIONS.fetch(word) if WORD_INFLECTIONS.key?(word)

      case word
      when /oes\z/
        word.delete_suffix("es")
      when /s\z/
        word.match?(/(?:ss|us)\z/) ? word : word.delete_suffix("s")
      else
        word
      end
    end
    private_class_method :normalize_word
  end
end
