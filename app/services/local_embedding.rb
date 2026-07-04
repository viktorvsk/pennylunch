# Wraps the local Informers sentence-transformer embedding pipeline used for
# ingredient-vector search.
#
# Memoizes the model process-wide and returns the embedding vector for non-blank
# text. Blank text returns `nil`, which lets callers skip indexing or vector
# filtering when there is nothing meaningful to embed.
class LocalEmbedding
  MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"

  class << self
    def model
      @model ||= Informers.pipeline(
        "embedding",
        MODEL_NAME,
        cache_dir: SETTINGS.informers_cache_dir
      )
    end

    def call(text)
      return if text.blank?

      model.call(text)
    end
  end
end
