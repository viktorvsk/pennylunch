class Avo::Actions::SetRecipeSearchStrategy < Avo::BaseAction
  self.name = "Set recipe search strategy"
  self.message = "Queue recipe search strategy update?"
  self.confirm_button_label = "Queue strategy update"
  self.standalone = true

  def fields
    field :strategy, as: :select, options: { "Overlap" => "overlap", "Vector" => "vector" }, default: "overlap", required: true
  end

  def handle(fields:, **)
    strategy = fields[:strategy].to_s
    return error("Unknown recipe search strategy.").keep_modal_open unless SetRecipeSearchStrategyJob::STRATEGIES.include?(strategy)

    SetRecipeSearchStrategyJob.perform_later(strategy)
    succeed "Queued recipe search strategy update to #{strategy}."
    reload
  end
end
