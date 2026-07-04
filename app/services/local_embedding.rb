class LocalEmbedding
  MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"

  def self.model
    @model ||= Informers.pipeline(
      "embedding",
      MODEL_NAME,
      cache_dir: SETTINGS.informers_cache_dir,
    )
  end

  def self.call(text)
    model.call(text)
  end

  def self.warm!
    model
  end
end
