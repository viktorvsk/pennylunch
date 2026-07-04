FactoryBot.define do
  factory :ingredient do
    sequence(:name) { |index| "ingredient #{index}" }
    aliases { [ name ] }
    optional { false }
  end
end
