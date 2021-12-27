class CMYKColour {
  float cyan;
  float magenta;
  float yellow;
  float black;

  // Construct from values
  CMYKColour(float c, float m, float y, float k) {
    this.cyan = c;
    this.magenta = m;
    this.yellow = y;
    this.black = k;
  }

  // Construct from RGB color object
  CMYKColour(color rgb) {
    float R1 = red(rgb) / 255;
    float G1 = green(rgb) / 255;
    float B1 = blue(rgb) / 255;
    float divisor = max(R1, G1, B1);
    float K = 1 - divisor;
    if (divisor > 0) {
      float C = (1-R1-K) / divisor;
      float M = (1-G1-K) / divisor;
      float Y = (1-B1-K) / divisor;
      this.cyan = C;
      this.magenta = M;
      this.yellow = Y;
    }
    this.black = K;
  }

  color getRGBcolor() {
    float r = round(255 * (1-cyan) * (1-black));
    float g = round(255 * (1-magenta) * (1-black));
    float b = round(255 * (1-yellow) * (1-black));
    return color(r, g, b);
  }

  color getCyan() {
    float r = 0;
    float g = 255 * cyan;
    float b = 255 * cyan;
    return color(r, g, b);
  }

  color getMagenta() {
    float r = 255 * magenta;
    float g = 0;
    float b = 255 * magenta;
    return color(r, g, b);
  }

  color getYellow() {
    float r = 255 * yellow;
    float g = 255 * yellow;
    float b = 0;
    return color(r, g, b);
  }

  color getBlack() {
    float r = 255 * (1 - black);
    float g = 255 * (1 - black);
    float b = 255 * (1 - black);
    return color(r, g, b);
  }

  float getInkIntensity(String ink) {
    switch(ink) {
    case "c":
      return cyan;
    case "m":
      return magenta;
    case "y":
      return yellow;
    case "k":
    default:
      return black;
    }
  }

  String toString() {
    return nf(cyan, 0, 2) +
      "," + nf(magenta, 0, 2) +
      "," + nf(yellow, 0, 2) +
      "," + nf(black, 0, 2);
  }
}
