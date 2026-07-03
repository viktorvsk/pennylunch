module Maintenance
  class WarmEmbeddingModelTask < MaintenanceTasks::Task
    no_collection

    def process
      LocalEmbedding.warm!
    end
  end
end
