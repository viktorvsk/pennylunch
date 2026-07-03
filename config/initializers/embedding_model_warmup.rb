Rails.application.config.after_initialize do
  config = Rails.application.config.penny_lunch
  next if Rails.env.test?
  next unless defined?(Rails::Server)
  next unless ActiveModel::Type::Boolean.new.cast(config.embedding_model_preload)

  Thread.new do
    Rails.application.executor.wrap do
      LocalEmbedding.warm!
    rescue StandardError => error
      Rails.logger.warn("Embedding model warmup failed: #{error.class}: #{error.message}")
    end
  end
end
