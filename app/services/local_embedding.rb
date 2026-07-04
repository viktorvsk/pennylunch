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
      model.call(text)
    end
  end
end
