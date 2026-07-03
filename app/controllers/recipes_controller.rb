class RecipesController < ApplicationController
  def index
    search = Recipes::Search.new(params: recipe_params).call
    render locals: { search:, recipes: search.recipes }
  end

  def show
    recipe = Recipe.find_by!(slug: params[:slug])
    render locals: { recipe: }
  end

  private

  def recipe_params
    params.permit(:q, :category, :ingredients, :quick, :popular, :sort, :page)
  end
end
