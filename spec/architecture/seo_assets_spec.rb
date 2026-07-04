# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SEO assets" do
  it "allows public pages and keeps operational endpoints out of robots.txt" do
    robots = Rails.root.join("public/robots.txt").read

    expect(robots).to include("User-agent: *")
    expect(robots).to include("Allow: /")
    expect(robots).to include("Disallow: /avo")
    expect(robots).to include("Disallow: /up")
    expect(robots).to include("Disallow: /ingredient_image")
    expect(robots).to include("Sitemap: http://127.0.0.1:3000/sitemap.xml")
  end

  it "lists stable public entry points in the static sitemap" do
    sitemap = Rails.root.join("public/sitemap.xml").read
    document = Nokogiri::XML(sitemap) { |config| config.strict }
    namespace = { "sitemap" => "http://www.sitemaps.org/schemas/sitemap/0.9" }

    urls = document.xpath("//sitemap:url/sitemap:loc", namespace).map(&:text)

    expect(document.root.name).to eq("urlset")
    expect(urls).to eq([
      "http://127.0.0.1:3000/",
      "http://127.0.0.1:3000/recipes"
    ])
    expect(urls).not_to include(a_string_including("/avo"))
    expect(urls).not_to include(a_string_including("/up"))
    expect(urls).not_to include(a_string_including("/ingredient_image"))
  end
end
