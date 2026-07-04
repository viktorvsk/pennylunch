module Maintenance
  # Imports the recipe source gzip into an empty recipes table.
  #
  # What it changes:
  # It creates Recipe rows from a gzipped JSON source. The task does not update existing recipes and does
  # not rebuild vectors for already-imported data.
  #
  # Why this exists:
  # Recipe import is an operator-controlled data load, not a request-time workflow. Keeping it as a
  # Maintenance Task gives local operators an explicit URL parameter, progress tracking, and the normal
  # `/maintenance_tasks` authentication boundary while keeping `RecipeImport` free of hidden
  # environment configuration.
  #
  # How it works:
  # The task exposes a `url` parameter prefilled with the PennyLunch interview asset URL, validates that it
  # is present, then passes it directly to `RecipeImport.call`. The service downloads, validates, parses,
  # derives search fields, and writes the rows with PostgreSQL COPY.
  class ImportRecipesTask < MaintenanceTasks::Task
    DEFAULT_URL = "https://pennylane-interviewing-assets-20220328.s3.eu-west-1.amazonaws.com/recipes-en.json.gz"

    attribute :url, :string, default: DEFAULT_URL
    validates :url, presence: true

    no_collection

    def process
      RecipeImport.call(url:)
    end
  end
end
