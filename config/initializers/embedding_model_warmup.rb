Rails.application.config.after_initialize do
  next if Rails.env.test?
  next unless defined?(Rails::Server)
  next unless ActiveModel::Type::Boolean.new.cast(SETTINGS.embedding_model_preload)

  Thread.new do
    Rails.application.executor.wrap do
      LocalEmbedding.model
    rescue StandardError => error
      Rails.logger.warn("Embedding model warmup failed: #{error.class}: #{error.message}")
    end
  end
end
