module Ingredients
  class BootstrapFromRecipeNames
    def self.call
      SyncFromAliasCatalog.call
    end
  end
end
