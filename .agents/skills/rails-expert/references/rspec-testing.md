# RSpec Testing

Use this reference when writing Rails specs, setting up RSpec, or improving TDD discipline.

## Repo Check

Before writing specs, inspect:

- `Gemfile`
- `.rspec`
- `spec/rails_helper.rb`
- `spec/spec_helper.rb`
- `spec/factories/**/*`

This repo currently has `rspec-rails`, `shoulda-matchers`, `factory_bot_rails`, `faker`, and `webmock` in the Gemfile, but may not have generated `spec/` files yet. Do not assume Devise, SimpleCov, DatabaseCleaner, Selenium, Capybara, or FFaker are installed.

If RSpec is not installed in the app structure yet:

```bash
bin/rails generate rspec:install
```

Add setup only for gems that exist. A minimal `rails_helper` usually includes FactoryBot syntax and Shoulda Matchers:

```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

Do not add DatabaseCleaner by default. Rails transactional tests are enough until the app has a concrete system-test or multi-threaded cleanup problem.

## TDD Loop

1. Name the behavior in one sentence.
2. Write the smallest failing spec that proves that behavior.
3. Run the targeted spec:

```bash
bundle exec rspec spec/services/recipe_matcher_spec.rb
bundle exec rspec spec/services/recipe_matcher_spec.rb:17
```

4. Confirm the failure is the expected missing behavior, not a setup or syntax error.
5. Implement the least code that satisfies the behavior.
6. Re-run the targeted spec.
7. Add edge-case specs only after the happy-path contract is green.
8. Run adjacent specs or full suite based on blast radius.

Use `--format documentation` when diagnosing spec intent and `--fail-fast` only for local debugging.

## RSpec Style

Prefer clear behavior structure:

```ruby
require "rails_helper"

RSpec.describe RecipeMatcher do
  subject(:result) { described_class.call(ingredients:, max_missing:) }

  let(:ingredients) { ["eggs", "spinach", "rice"] }
  let(:max_missing) { 1 }

  it "returns recipes that can be made with the available ingredients" do
    recipe = create(:recipe, ingredients: ["eggs", "spinach"])

    expect(result).to include(recipe)
  end
end
```

Rules:

- Use `describe ".call"` for class methods and `describe "#method_name"` for instance methods when helpful.
- Prefer `subject(:result)` for the action under test.
- Use `let` for lazy inputs; use `let!` only when eager persistence is part of the setup.
- Keep examples focused on one behavior. Multiple expectations are fine when they describe the same result; use `aggregate_failures` for readability.
- Avoid testing private methods directly.
- Avoid `allow_any_instance_of`. Stub explicit collaborators or isolate boundary objects.
- Use `travel_to` for time-dependent behavior.
- Use WebMock for external HTTP and assert request shape at the boundary.

## FactoryBot

Factories should be minimal, valid, and explicit.

```ruby
FactoryBot.define do
  sequence(:ingredient_name) { |n| "ingredient-#{n}" }
  sequence(:recipe_slug) { |n| "recipe-#{n}" }

  factory :ingredient do
    name { generate(:ingredient_name) }
  end

  factory :recipe do
    name { "Spinach omelette" }
    slug { generate(:recipe_slug) }
    ready_in_minutes { 15 }

    trait :with_ingredients do
      transient do
        ingredient_names { ["eggs", "spinach"] }
      end

      after(:create) do |recipe, evaluator|
        evaluator.ingredient_names.each do |name|
          ingredient = create(:ingredient, name:)
          create(:recipe_ingredient, recipe:, ingredient:)
        end
      end
    end
  end
end
```

Use the right persistence level:

- `build` for validations and pure object behavior.
- `build_stubbed` when code needs an id-like object but should not query, reload, or persist.
- `create` when the behavior depends on database queries, constraints, callbacks, associations, or transactions.
- `create_list` only when count matters. Keep list sizes small.

Factory rules:

- Use sequences for unique fields.
- Keep random-looking defaults out of asserted values.
- Put expensive association creation behind traits.
- Prefer explicit associations in examples when the relationship is central to the behavior.
- Do not hide important setup in callbacks that every factory pays for.

## Faker And FFaker

`faker` and `ffaker` are different gems with different namespaces.

- If `Gemfile` has `faker`, use `Faker::`.
- If `Gemfile` has `ffaker`, use `FFaker::`.
- Do not mix namespaces.
- Do not add or switch to `ffaker` unless the dependency change is intentional.

This repo currently uses `faker`, so factories should use `Faker::` when fake data is useful:

```ruby
factory :user do
  email { Faker::Internet.unique.email }
  name { Faker::Name.name }
end
```

If the repo later switches to FFaker:

```ruby
factory :user do
  email { FFaker::Internet.email }
  name { FFaker::Name.name }
end
```

Use Faker/FFaker sparingly:

- Good: plausible default names, URLs, paragraphs, or emails where the exact value is irrelevant.
- Bad: values that are asserted in the spec, values that must satisfy tight validations, dates/times that can make tests flaky, random counts, random enum values, or generated strings that obscure the domain.
- For PennyLunch, prefer deterministic domain data in examples: `"eggs"`, `"spinach"`, `"Spinach omelette"`, `15.minutes`, `2` missing ingredients.

Clear Faker uniqueness when needed:

```ruby
RSpec.configure do |config|
  config.before { Faker::UniqueGenerator.clear }
end
```

Only add this if uniqueness exhaustion appears in real specs.

## Model Specs

```ruby
require "rails_helper"

RSpec.describe Ingredient, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "normalizes names before validation" do
      ingredient = described_class.new(name: "  Eggs  ")

      ingredient.validate

      expect(ingredient.name).to eq("eggs")
    end
  end
end
```

Use Shoulda Matchers for simple Rails declarations, then write explicit examples for business behavior.

## Request Specs

```ruby
require "rails_helper"

RSpec.describe "Recipe searches", type: :request do
  describe "POST /recipe_searches" do
    it "creates a search from submitted ingredients" do
      post recipe_searches_path, params: {
        recipe_search: { ingredients: "eggs, spinach" }
      }

      expect(response).to redirect_to(recipe_search_path(RecipeSearch.last))
      expect(RecipeSearch.last.ingredients).to contain_exactly("eggs", "spinach")
    end

    it "returns unprocessable entity for blank ingredients" do
      post recipe_searches_path, params: {
        recipe_search: { ingredients: "" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

Do not use `sign_in` or Devise helpers unless the app has Devise or equivalent helpers configured.

## Job Specs

```ruby
require "rails_helper"

RSpec.describe ImportRecipesJob, type: :job do
  include ActiveJob::TestHelper

  it "enqueues on the default queue" do
    expect {
      described_class.perform_later("https://example.test/feed.json")
    }.to have_enqueued_job(described_class)
      .with("https://example.test/feed.json")
      .on_queue("default")
  end

  it "imports recipes from the feed" do
    stub_request(:get, "https://example.test/feed.json")
      .to_return(status: 200, body: { recipes: [] }.to_json)

    described_class.perform_now("https://example.test/feed.json")

    expect(WebMock).to have_requested(:get, "https://example.test/feed.json")
  end
end
```

For Solid Queue jobs, assert Active Job behavior and idempotency. Do not depend on the queue backend internals unless the task is specifically Solid Queue configuration.

## System Specs

Use system specs only when browser behavior matters: Turbo Frames/Streams, Stimulus, JavaScript UI, or important end-to-end forms.

Do not add Selenium/Capybara driver assumptions unless the repo has configured them. If browser verification is needed before system specs exist, run the app and verify with browser automation instead, then add proper system setup as a deliberate task.
