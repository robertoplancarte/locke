# A tenant brand color, given as a "#RRGGBB" hex string.
BrandColor = Data.define(:hex) do
  # WCAG relative luminance above which dark text has better contrast than white
  # (the point where both contrast ratios are equal).
  LUMINANCE_THRESHOLD = 0.179

  def to_s = hex

  # Black or white, whichever is more legible on top of this color.
  def foreground
    luminance > LUMINANCE_THRESHOLD ? "#000000" : "#FFFFFF"
  end

  def luminance
    red, green, blue = hex.delete_prefix("#").scan(/../).map { |channel| linearize(channel.to_i(16) / 255.0) }
    0.2126 * red + 0.7152 * green + 0.0722 * blue
  end

  private

  def linearize(value)
    value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
  end
end
