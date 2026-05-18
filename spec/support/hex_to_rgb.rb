# Helper to convert hex colors to the rgb() string format returned by
# getComputedStyle in Selenium (used by design-token system specs).
#
# Browsers normalize CSS color values to "rgb(r, g, b)" with spaces after
# commas (no leading zeros). This helper produces that exact format so
# specs can `eq` against `page.evaluate_script("...backgroundColor")`.
module HexToRgb
  # Radical palette primitives (light + dark) — kept in sync with
  # `specs/065-design-tokens-2-layers/data-model.md` §1.
  PRIMITIVES = {
    rad_prim_cream:           "#fbf7ee",
    rad_prim_paper_light:     "#ffffff",
    rad_prim_paper_dark:      "#143b40",
    rad_prim_raise_light:     "#fdfaf3",
    rad_prim_raise_dark:      "#1a4a50",
    rad_prim_warm_light:      "#e8e0cc",
    rad_prim_warm_dark:       "#1a4a50",
    rad_prim_ink_light:       "#0e1b1f",
    rad_prim_ink_dark:        "#f5ecdc",
    rad_prim_muted_light:     "#6b665a",
    rad_prim_muted_dark:      "#a8c2c5",
    rad_prim_rule_light:      "#e6dcc1",
    rad_prim_rule_dark:       "#22585e",
    rad_prim_balisier_red_light: "#d4452e",
    rad_prim_balisier_red_dark:  "#e85a44",
    rad_prim_sun_yellow_light:   "#e8b53f",
    rad_prim_sun_yellow_dark:    "#f0c25e",
    rad_prim_sea_teal_light:     "#127566",
    rad_prim_sea_teal_dark:      "#5fc5b8",
    rad_prim_grass_green_light:  "#2e8b3a",
    rad_prim_grass_green_dark:   "#7bc77a"
  }.freeze

  def hex_to_rgb(hex)
    cleaned = hex.delete_prefix("#").strip
    raise ArgumentError, "Invalid hex color: #{hex.inspect}" unless cleaned.match?(/\A[0-9a-fA-F]{6}\z/)

    r = cleaned[0, 2].to_i(16)
    g = cleaned[2, 2].to_i(16)
    b = cleaned[4, 2].to_i(16)
    "rgb(#{r}, #{g}, #{b})"
  end
end

RSpec.configure { |config| config.include HexToRgb } if defined?(RSpec)
