require "rails_helper"

RSpec.describe LocalEmbedding do
  it "returns real finite vectors from the local embedding model" do
    vector = described_class.call("tomato\npasta")

    expect(vector.size).to eq(384)
    expect(vector).to all(be_a(Float))
    expect(vector).to all(satisfy(&:finite?))
  end

  it "places related ingredient text closer than unrelated ingredient text" do
    query = described_class.call("tomato\npasta")
    related = described_class.call("tomato\nspaghetti\nsauce")
    unrelated = described_class.call("apple\ncinnamon\ncake")

    expect(cosine_similarity(query, related)).to be > cosine_similarity(query, unrelated)
  end

  def cosine_similarity(left, right)
    dot_product = left.zip(right).sum { |left_value, right_value| left_value * right_value }
    left_norm = Math.sqrt(left.sum { |value| value * value })
    right_norm = Math.sqrt(right.sum { |value| value * value })
    dot_product / (left_norm * right_norm)
  end
end
