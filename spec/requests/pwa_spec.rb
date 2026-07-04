# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PWA manifest", type: :request do
  it "describes the installable app icon set" do
    get "/manifest.json"

    expect(response).to have_http_status(:ok)

    manifest = JSON.parse(response.body)
    icons = manifest.fetch("icons")

    expect(manifest).to include(
      "name" => "PennyLunch",
      "short_name" => "PennyLunch",
      "start_url" => "/",
      "display" => "standalone",
      "theme_color" => "#f97316",
      "background_color" => "#ffffff"
    )
    expect(icons).to include(
      { "src" => "/pen.svg", "type" => "image/svg+xml", "sizes" => "any" },
      { "src" => "/icon-64x64.png", "type" => "image/png", "sizes" => "64x64" },
      { "src" => "/icon-192x192.png", "type" => "image/png", "sizes" => "192x192" },
      { "src" => "/icon-512x512.png", "type" => "image/png", "sizes" => "512x512" },
      { "src" => "/icon-maskable-192x192.png", "type" => "image/png", "sizes" => "192x192", "purpose" => "maskable" },
      { "src" => "/icon-maskable-512x512.png", "type" => "image/png", "sizes" => "512x512", "purpose" => "maskable" }
    )
  end
end
