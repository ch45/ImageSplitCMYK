/**
 * ImageSplitCMYK
 * 1. draw the input image
 * 2. sum colour components into a smaller picture at a given spacing
 * 3. convert the smaller pictures into CMYK separations
 * 4. draw the polar rotations
 * 5. save to a PDF
 */

import processing.pdf.*;
import processing.svg.*;

String inputFile = "";
final static int minGridSpacing = 2;
final static int maxGridSpacing = 32;
int gridSpacing = 25;
static final float penWidth = 0.5; // in mm
final static int longEdgeDots = 1754; // A4 150dpi
final static int shortEdgeDots = 1240;
PShape saveIcon;
Point panelCorner;
PImage inputPicture;
PImage smallPictureRed;
PImage smallPictureGreen;
PImage smallPictureBlue;
PImage smallPictureCyan;
PImage smallPictureMagenta;
PImage smallPictureYellow;
PImage smallPictureBlack;
PImage outputPicture;
Dimension outputPictureDim;
Dimension smallPictureDim;
int lastWidth;
int lastHeight;
boolean doRedraw = false;
CMYKColour[][] cmykImageData;
static final JSONObject mapInkIndex = JSONObject.parse("{\"c\": 0, \"m\": 1, \"y\": 2, \"k\": 3}");
static final String[] inksList = {"c", "m", "y", "k"};
static final int WAIT = 0;
static final int REQUIRED = 1;
static final int RUNNING = 2;
static final int DONE = 3;
int statusReadFile = WAIT;
int statusInitComponentImages = WAIT;
int statusSumColourComponents = WAIT;
int statusCMYKExtraction = WAIT;
int statusCreatePrint = WAIT;
int statusSavePrint = WAIT;
ArrayList<ScribbleLine>[] scribbleLines;

void setup() {
  size(1024, 768);
  surface.setResizable(true);
  saveIcon = loadShape("save.svg"); // https://www.svgrepo.com/svg/155614/save
  nextFile();
  // noStroke();
  noSmooth();
}

void draw() {
  doProcessing();
  int tempWidth = width;
  int tempHeight = height;
  if (lastWidth != tempWidth || lastHeight != tempHeight || doRedraw) {
    redrawEverything();
    lastWidth = tempWidth;
    lastHeight = tempHeight;
    doRedraw = false;
  }
}

void mouseReleased() {
  controlPanelAction(mouseX, mouseY, "mouseReleased");
}

void doProcessing() {
  if (statusReadFile == WAIT) { // Reset
    statusReadFile = REQUIRED;
    statusInitComponentImages = WAIT;
    statusSumColourComponents = WAIT;
    statusCMYKExtraction = WAIT;
    statusCreatePrint = WAIT;
    statusSavePrint = WAIT;
  }
  if (statusReadFile == REQUIRED) {
    thread("readImageFile");
  } else if (statusInitComponentImages == REQUIRED) {
    thread("initComponentImages");
  } else if (statusSumColourComponents == REQUIRED) {
    thread("sumColourComponents");
  } else if (statusCMYKExtraction == REQUIRED) {
    thread("cmykExtraction");
  } else if (statusCreatePrint == REQUIRED) {
    thread("createPrint");
  } else if (statusSavePrint == REQUIRED) {
    thread("savePrint");
  }
}

void readImageFile() {
  statusReadFile = RUNNING;
  println("inputFile=" + inputFile);
  if (inputFile != "") {
    inputPicture = loadImage(inputFile); // Load the image into the program
    statusReadFile = DONE;
    statusInitComponentImages = REQUIRED;
  } else {
    println("Please create a data directory and add some image files");
  }
}

void initComponentImages() {
  statusInitComponentImages = RUNNING;
  smallPictureDim = new Dimension(inputPicture.width / gridSpacing, inputPicture.height / gridSpacing);
  Dimension dim = smallPictureDim;
  cmykImageData = new CMYKColour[dim.h][dim.w];
  smallPictureRed = createImage(dim.w, dim.h, RGB);
  smallPictureGreen = createImage(dim.w, dim.h, RGB);
  smallPictureBlue = createImage(dim.w, dim.h, RGB);
  smallPictureCyan = createImage(dim.w, dim.h, RGB);
  smallPictureMagenta = createImage(dim.w, dim.h, RGB);
  smallPictureYellow = createImage(dim.w, dim.h, RGB);
  smallPictureBlack = createImage(dim.w, dim.h, RGB);
  outputPicture = createImage(1, 1, RGB); // an initial pixel then set white and resize to that of the paper
  outputPicture.set(0, 0, #FFFFFF);
  outputPictureDim = scaleDimensionIgnoreOrientation(inputPicture.width, inputPicture.height, longEdgeDots, shortEdgeDots);
  outputPicture.resize(outputPictureDim.w, outputPictureDim.h);
  initScribbleData();
  doRedraw = true;
  statusInitComponentImages = DONE;
  statusSumColourComponents = REQUIRED;
}

void initScribbleData() {
  scribbleLines = (ArrayList<ScribbleLine>[])new ArrayList[4];
  for (int j = 0; j < inksList.length; j++) {
    scribbleLines[j] = new ArrayList<ScribbleLine>();
  }
}

void saveScribbleDataSVG(String svgSaveFile) {
  println("Saving to " + svgSaveFile + " ...");
  int numLines = 0;
  PGraphics svg = createGraphics(outputPictureDim.w, outputPictureDim.h, SVG, svgSaveFile);
  svg.beginDraw();
  svg.background(255);
  svg.strokeWeight(penWidth);
  for (String ink : inksList) {
    color dotColour = getRGBfromInk(ink);
    svg.stroke(dotColour);
    boolean startedShape = false;
    for (ScribbleLine line : scribbleLines[mapInkToIndex(ink)]) {
      if (!startedShape) {
        svg.beginShape(); // default POLYGON => SVG path
        numLines--;
        startedShape = true;
      } else if (line.moveTo) {
        svg.endShape();
        svg.beginShape();
        numLines--;
      }
      svg.vertex(line.x, line.y);
      numLines++;
    }
    if (startedShape) {
      svg.endShape();
    }
  }
  svg.dispose();
  svg.endDraw();
  println("...done (numLines=" + numLines + ")");
}

void sumColourComponents() {
  statusSumColourComponents = RUNNING;
  for (int y = 0; y < inputPicture.height / gridSpacing; y++) {
    for (int x = 0; x < inputPicture.width / gridSpacing; x++) {
      color c = aggrateAroundGrid(x * gridSpacing, y * gridSpacing);
      color colourRed = color(red(c), 0, 0);
      color colourGreen = color(0, green(c), 0);
      color colourBlue = color(0, 0, blue(c));
      smallPictureRed.set(x, y, colourRed);
      smallPictureGreen.set(x, y, colourGreen);
      smallPictureBlue.set(x, y, colourBlue);
    }
  }
  doRedraw = true;
  statusSumColourComponents = DONE;
  statusCMYKExtraction = REQUIRED;
}

void cmykExtraction() {
  statusCMYKExtraction = RUNNING;
  for (int y = 0; y < smallPictureDim.h; y++) {
    for (int x = 0; x < smallPictureDim.w; x++) {
      float colourRed = red(smallPictureRed.get(x, y));
      float colourGreen = green(smallPictureGreen.get(x, y));
      float colourBlue = blue(smallPictureBlue.get(x, y));
      color rgb = color(colourRed, colourGreen, colourBlue);
      CMYKColour cmyk = new CMYKColour(rgb);
      cmykImageData[y][x] = cmyk;
      smallPictureCyan.set(x, y, cmyk.getCyan());
      smallPictureMagenta.set(x, y, cmyk.getMagenta());
      smallPictureYellow.set(x, y, cmyk.getYellow());
      smallPictureBlack.set(x, y, cmyk.getBlack());
    }
  }
  doRedraw = true;
  statusCMYKExtraction = DONE;
  statusCreatePrint = REQUIRED;
}

void createPrint() {
  statusCreatePrint = RUNNING;
  createPrintScribble();
  doRedraw = true;
  statusCreatePrint = DONE;
}

void createPrintScribble() {
  Dimension offset = new Dimension(gridSpacing / 2, gridSpacing / 2);
  float scale = (float)outputPictureDim.w / smallPictureDim.w;
  println("gridSpacing", gridSpacing, "offset", offset.w, offset.h, "scale", scale);
  for (String ink : inksList) {
    cmykPrintInkScribble(offset, scale, ink);
  }
}

void cmykPrintInkScribble(Dimension offset, float scale, String ink) {
  int rows = smallPictureDim.h;
  int cols = smallPictureDim.w;
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      CMYKColour cmyk = cmykImageData[y][x];
      cmykPrintScribbleLines(x, y, offset, scale, ink, cmyk);
    }
  }
}

void cmykPrintScribbleLines(int x, int y, Dimension offset, float scale, String ink, CMYKColour cmyk) {
  // println("scale", scale, "ink", ink);
  color dotColour = getRGBfromInk(ink);
  float intensity = cmyk.getInkIntensity(ink);
  Dimension dim = new Dimension(gridSpacing * 2, gridSpacing * 2); // TODO may be x2 to allow for overlapping
  PGraphics pg = createGraphics(dim.w, dim.h);
  pg.beginDraw();
  if (ink.equals("c")) {
    pg.background(255);
  }
  pg.stroke(dotColour);
  drawScribbles(pg, scribbleLines[mapInkToIndex(ink)], x, y, offset, gridSpacing / 2, scale, intensity);
  pg.endDraw();
  PImage img = pg.get();
  image(img, 0, 0);
  outputPicture.blend(img, 0, 0, dim.w, dim.h, floor(x * scale), floor(y * scale), dim.w, dim.h, BLEND);
}

void drawScribbles(PGraphics pg, ArrayList<ScribbleLine> scribble, int x, int y, Dimension offset, float radius, float scale, float intensity) {

  if (intensity == 0) {
    return;
  }

  fpPoint[] points = getRandomPointsOnCircumference(offset, radius, 2);
  fpPoint centre = new fpPoint((points[0].x + points[1].x) / 2, (points[0].y + points[1].y) / 2);

  fpPoint[] perpenPts = getPerpendicularPointsAtDistance(centre, points[0], radius / 2);

  fpPoint[] boundaryLinePtsA = getPerpendicularPointsAtDistance(perpenPts[0], centre, radius * 1.4);
  fpPoint[] boundaryLinePtsB = getPerpendicularPointsAtDistance(perpenPts[1], centre, radius * 1.4);

  int step = 1;
  float len = radius;
  float limit = (intensity + 1) * len / 2;
  int end = (int)limit;
  int start = end - (int)(intensity * len);
  int j = start;

  float m0;
  float m1;
  float c1;
  float m2;
  float c2;
  float x1;
  float y1;
  float x2;
  float y2;

  boolean along_x_axis = abs(points[0].x - centre.x) > abs(points[0].y - centre.y);
  if (along_x_axis) {
    // y = mx + c;
    m0 = (points[0].y - centre.y) / (points[0].x - centre.x);
    m1 = (perpenPts[0].y - boundaryLinePtsA[0].y) / (perpenPts[0].x - boundaryLinePtsA[0].x);
    c1 = boundaryLinePtsA[0].y - m1 * boundaryLinePtsA[0].x;
    m2 = (perpenPts[1].y - boundaryLinePtsB[0].y) / (perpenPts[1].x - boundaryLinePtsB[0].x);
    c2 = boundaryLinePtsB[0].y - m2 * boundaryLinePtsB[0].x;
    x1 = map(j, 0, len, boundaryLinePtsB[1].x, boundaryLinePtsB[0].x);
    y1 = x1 * m0 + c2;
    x2 = map(j, 0, len, boundaryLinePtsA[0].x, boundaryLinePtsA[1].x);
    y2 = x2 * m0 + c1;
  } else {
    // x = my + c;
    m0 = (points[0].x - centre.x) / (points[0].y - centre.y);
    m1 = (perpenPts[0].x - boundaryLinePtsA[0].x) / (perpenPts[0].y - boundaryLinePtsA[0].y);
    c1 = boundaryLinePtsA[0].x - m1 * boundaryLinePtsA[0].y;
    m2 = (perpenPts[1].x - boundaryLinePtsB[0].x) / (perpenPts[1].y - boundaryLinePtsB[0].y);
    c2 = boundaryLinePtsB[0].x - m2 * boundaryLinePtsB[0].y;
    y1 = map(j, 0, len, boundaryLinePtsB[1].y, boundaryLinePtsB[0].y);
    x1 = y1 * m0 + c2;
    y2 = map(j, 0, len, boundaryLinePtsA[0].y, boundaryLinePtsA[1].y);
    x2 = y2 * m0 + c1;
  }
  int pass = 0;
  for (; j <= end; j += step) {
    pass++;
    float old_x1 = x1;
    float old_y1 = y1;
    float old_x2 = x2;
    float old_y2 = y2;
    if (along_x_axis) {
      x1 = map(j, 0, len, boundaryLinePtsB[1].x, boundaryLinePtsB[0].x);
      y1 = x1 * m0 + c2;
      x2 = map(j, 0, len, boundaryLinePtsA[0].x, boundaryLinePtsA[1].x);
      y2 = x2 * m0 + c1;
    } else {
      y1 = map(j, 0, len, boundaryLinePtsB[1].y, boundaryLinePtsB[0].y);
      x1 = y1 * m0 + c2;
      y2 = map(j, 0, len, boundaryLinePtsA[0].y, boundaryLinePtsA[1].y);
      x2 = y2 * m0 + c1;
    }
    if (pass > 1) { // along the boundary line
      if (pass % 2 == 0) {
        pg.line(old_x1,old_y1, x1,y1);
        scribble.add(new ScribbleLine(false, x * scale + x1, y * scale + y1));
      } else {
        pg.line(old_x2,old_y2, x2,y2);
        scribble.add(new ScribbleLine(false, x * scale + x2, y * scale + y2));
      }
    }
    if (j + step > end) { // between the lines
      if (pass % 2 == 0) {
        x2 = map(limit - end, 0, 1, x1, x2);
        y2 = map(limit - end, 0, 1, y1, y2);
      } else {
        x1 = map(limit - end, 0, 1, x2, x1);
        y1 = map(limit - end, 0, 1, y2, y1);
      }
    }
    if (pass % 2 == 0) {
      pg.line(x1,y1, x2,y2);
      scribble.add(new ScribbleLine(pass == 1, x * scale + x1, y * scale + y1));
      scribble.add(new ScribbleLine(false, x * scale + x2, y * scale + y2));
    } else {
      pg.line(x2,y2, x1,y1);
      scribble.add(new ScribbleLine(pass == 1, x * scale + x2, y * scale + y2));
      scribble.add(new ScribbleLine(false, x * scale + x1, y * scale + y1));
    }
  }
}

fpPoint[] getPerpendicularPointsAtDistance(fpPoint p1, fpPoint p2, float distance) {
  fpPoint[] perpenPts = new fpPoint[2];
  float dx = p2.x - p1.x;
  float dy = p2.y - p1.y;
  float dist = sqrt(sq(dx) + sq(dy));
  perpenPts[0] = new fpPoint(p1.x + distance * dy / dist, p1.y - distance * dx / dist);
  perpenPts[1] = new fpPoint(p1.x - distance * dy / dist, p1.y + distance * dx / dist);
  return perpenPts;
}

fpPoint[] getRandomPointsOnCircumference(Dimension offset, float radius, int num) {
  fpPoint[] points = new fpPoint[num];
  for (int j = 0; j < points.length; j++) {
    float rAng = random(1, 360);
    float rRad = radians(rAng);
    float xA = offset.w + radius * cos(rRad);
    float yA = offset.h + radius * sin(rRad);
    points[j] = new fpPoint(xA, yA);
  }
  return points;
}

void savePrint() {
  statusSavePrint = RUNNING;
  String basename = inputFile.substring(0, inputFile.indexOf(".jpg"));
  if (keyPressed && key == CODED && keyCode == SHIFT) {
    String svgSaveFile = "output_" + basename + ".svg";
    saveScribbleDataSVG(svgSaveFile);
  } else {
    String pdfSaveFile = "output_" + basename + ".pdf";
    PGraphics pdf = createGraphics(outputPicture.width, outputPicture.height, PDF, pdfSaveFile);
    pdf.beginDraw();
    pdf.image(outputPicture, 0, 0);
    pdf.dispose();
    pdf.endDraw();
    println("Saved to " + pdfSaveFile);
  }
  // outputPicture.save("_output_" + basename + ".png");
  statusSavePrint = DONE;
}

void redrawEverything() {
  final float[] proportions = {0.354, 0.167, 0.125, 0.354};
  clearDisplayWindow();
  if (statusReadFile == DONE) {
    int dwidth = floor(proportions[0] * width);
    int dheight = floor((float)inputPicture.height / inputPicture.width * dwidth);
    PImage img = createImage(dwidth, dheight, RGB);
    img.copy(inputPicture, 0, 0, inputPicture.width, inputPicture.height, 0, 0, dwidth, dheight);
    image(img, 0, 0);
  }
  if (statusSumColourComponents == DONE) {
    int dwidth = floor(proportions[1] * width);
    int dheight = floor((float)smallPictureRed.height / smallPictureRed.width * dwidth);
    PImage img = createImage(dwidth, dheight, RGB);
    img.copy(smallPictureRed, 0, 0, smallPictureRed.width, smallPictureRed.height, 0, 0, dwidth, dheight);
    image(img, proportions[0] * width, 0);
    img.copy(smallPictureGreen, 0, 0, smallPictureGreen.width, smallPictureGreen.height, 0, 0, dwidth, dheight);
    image(img, proportions[0] * width, dheight);
    img.copy(smallPictureBlue, 0, 0, smallPictureBlue.width, smallPictureBlue.height, 0, 0, dwidth, dheight);
    image(img, proportions[0] * width, 2 * dheight);
  }
  if (statusCMYKExtraction == DONE) {
    int dwidth = floor(proportions[2] * width);
    int dheight = floor((float)smallPictureCyan.height / smallPictureCyan.width * dwidth);
    PImage img = createImage(dwidth, dheight, RGB);
    img.copy(smallPictureCyan, 0, 0, smallPictureCyan.width, smallPictureCyan.height, 0, 0, dwidth, dheight);
    image(img, (proportions[0] + proportions[1]) * width, 0);
    img.copy(smallPictureMagenta, 0, 0, smallPictureMagenta.width, smallPictureMagenta.height, 0, 0, dwidth, dheight);
    image(img, (proportions[0] + proportions[1]) * width, dheight);
    img.copy(smallPictureYellow, 0, 0, smallPictureYellow.width, smallPictureYellow.height, 0, 0, dwidth, dheight);
    image(img, (proportions[0] + proportions[1]) * width, 2 * dheight);
    img.copy(smallPictureBlack, 0, 0, smallPictureBlack.width, smallPictureBlack.height, 0, 0, dwidth, dheight);
    image(img, (proportions[0] + proportions[1]) * width, 3 * dheight);
  }
  if (statusCreatePrint == DONE) {
    int dwidth = floor(proportions[3] * width);
    int dheight = floor((float)outputPicture.height / outputPicture.width * dwidth);
    PImage img = createImage(dwidth, dheight, RGB);
    img.copy(outputPicture, 0, 0, outputPicture.width, outputPicture.height, 0, 0, dwidth, dheight);
    image(img, (proportions[0] + proportions[1] + proportions[2]) * width, 0);
  }
  panelCorner = new Point(width / 24, (height - 30) * 11 / 12);
  controlPanelAction(panelCorner.x, panelCorner.y, "draw");
}

color aggrateAroundGrid(int gridX, int gridY) {
  int count = 0;
  int sumRed = 0;
  int sumGreen = 0;
  int sumBlue =0 ;
  for (int y = gridY; y < gridY + gridSpacing && y < inputPicture.height; y++) {
    for (int x = gridX; x < gridX + gridSpacing && x < inputPicture.width; x++) {
      color c = inputPicture.get(x, y);
      sumRed += red(c);
      sumGreen += green(c);
      sumBlue += blue(c);
      count++;
    }
  }
  return color(sumRed / count, sumGreen / count, sumBlue / count);
}

color getRGBfromInk(String ink) {
  switch(ink) {
  case "c":
    return color(0, 255, 255);
  case "m":
    return color(255, 0, 255);
  case "y":
    return color(255, 255, 0);
  case "k":
  default:
    return color(0, 0, 0);
  }
}

float getScreenAngle(String ink) {
  switch(ink) {
  case "c":
    return 15.0;
  case "m":
    return 75.0;
  case "y":
    return 0.0;
  case "k":
  default:
    return 45.0;
  }
}

Dimension scaleDimensionIgnoreOrientation(int srcX, int srcY, int targetLong, int targetShort) {
  int inLong = max(srcX, srcY);
  int inShort = min(srcX, srcY);
  float scale1 = (float)targetLong / inLong;
  float scale2 = (float)targetShort / inShort;
  if (scale1 <= scale2) {
    return new Dimension(scale1 * srcX, scale1 * srcY);
  } else {
    return new Dimension(scale2 * srcX, scale2 * srcY);
  }
}

void controlPanelAction(int x, int y, String action) {
  Point[][] corners = {
    {new Point(0,0), new Point(237,30)},
    {new Point(4,3), new Point(24,26)},
    {new Point(30,3), new Point(50,26)},
    {new Point(57,8), new Point(202,22)},
    {new Point(208,3), new Point(232,26)}};
  if (action == "draw") {
    drawControlPanel(x, y, corners);
  } else if (action == "mouseReleased") {
    mouseReleasedControlPanel(x - panelCorner.x, y - panelCorner.y, corners);
  }
}

void drawControlPanel(int x, int y, Point[][] corners) {
  noStroke();
  fill(#FFFFFF, 192);
  // draw a grey alpha shading as background
  rect(x + corners[0][0].x, y + corners[0][0].y,
       corners[0][1].x - corners[0][0].x, corners[0][1].y - corners[0][0].y, 3);
  // draw left arrow - previous file
  strokeCap(SQUARE);
  stroke(#A9A9A9);
  fill(#A9A9A9);
  strokeWeight(1);
  triangle(x + corners[1][0].x, y + (corners[1][0].y + corners[1][1].y) / 2,
           x + corners[1][1].x, y + corners[1][0].y,
           x + corners[1][1].x, y + corners[1][1].y);
  // draw right arry - next file
  triangle(x + corners[2][0].x, y + corners[2][0].y,
           x + corners[2][0].x, y + corners[2][1].y,
           x + corners[2][1].x, y + (corners[2][0].y + corners[2][1].y) / 2);
  // draw slider - set gridSpacing
  int weight = 5;
  strokeWeight(weight);
  line(x + corners[3][0].x, y + (corners[3][0].y + corners[3][1].y) / 2,
       x + corners[3][1].x, y + (corners[3][0].y + corners[3][1].y) / 2);
  int pos = round(map(gridSpacing, minGridSpacing, maxGridSpacing, corners[3][0].x, corners[3][1].x - weight));
  line(x + pos, y + corners[3][0].y,
       x + pos, y + corners[3][1].y);
  // draw diskette image - save to PDF
  shape(saveIcon,
        x + corners[4][0].x, y + corners[4][0].y,
        corners[4][1].x - corners[4][0].x, corners[4][1].y - corners[4][0].y);
}

void mouseReleasedControlPanel(int x, int y, Point[][] corners) {
  if (x < corners[0][0].x || x > corners[0][1].x || y < corners[0][0].y || y > corners[0][1].y) {
    // outide of the panel
    return;
  }
  // previous file
  if (x >= corners[1][0].x && x <= corners[1][1].x && y >= corners[1][0].y && y <= corners[1][1].y) {
    previousFile();
    statusReadFile = WAIT;
  }
  // next file
  if (x >= corners[2][0].x && x <= corners[2][1].x && y >= corners[2][0].y && y <= corners[2][1].y) {
    nextFile();
    statusReadFile = WAIT;
  }
  // set gridSpacing
  if (x >= corners[3][0].x && x <= corners[3][1].x && y >= corners[3][0].y && y <= corners[3][1].y) {
    gridSpacing = round(map(x, corners[3][0].x, corners[3][1].x, minGridSpacing, maxGridSpacing));
    if (statusReadFile == DONE) {
      statusInitComponentImages = REQUIRED;
      statusSavePrint = WAIT;
    }
    return;
  }
  // save to PDF
  if (x >= corners[4][0].x && x <= corners[4][1].x && y >= corners[4][0].y && y <= corners[4][1].y) {
    if (statusCreatePrint == DONE && statusSavePrint != RUNNING) {
      statusSavePrint = REQUIRED;
    }
  }
}

void previousFile() {
  String names[] = listFileNames(dataPath(""));
  String priorName = "";
  boolean uptoLast = false;
  if (names == null) {
    return;
  }
  for (String name : names) {
    if (isImageFile(name)) {
      if (uptoLast) {
        priorName = name;
      } else {
        if (name.equals(inputFile)) {
          if (priorName == "") {
            uptoLast = true;
          } else {
            break;
          }
        }
        priorName = name;
      }
    }
  }
  inputFile = priorName;
}

void nextFile() {
  String names[] = listFileNames(dataPath(""));
  String nextName = "";
  boolean seenCurrent = false;
  if (names == null) {
    return;
  }
  for (String name : names) {
    if (isImageFile(name)) {
      if (nextName == "") {
        nextName = name;
      }
      if (seenCurrent) {
        nextName = name;
        break;
      }
      if (name.equals(inputFile)) {
        seenCurrent = true;
      }
    }
  }
  inputFile = nextName;
}

// This function returns all the files in a directory as an array of Strings
String[] listFileNames(String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    String names[] = file.list();
    return names;
    // return filterImageFiles(names);
  } else {
    // If it's not a directory
    return null;
  }
}

boolean isImageFile(String name) {
  final String[] extensions = {".gif", ".jpg", ".tga", ".png"};
  for (String ext : extensions) {
    if (name.toLowerCase().indexOf(ext) > -1) {
      return true;
    }
  }
  return false;
}

void clearDisplayWindow() {
  // clear(); // to black
  PImage fill = createImage(1, 1, RGB);
  fill.set(0, 0, #CCCCCC);
  fill.resize(width, height);
  image(fill, 0, 0);
}

void cmykPrintInkPolar(float radius, float scale, String ink) {
  int rows = smallPictureDim.h;
  int cols = smallPictureDim.w;
  Dimension offset = new Dimension(radius, radius);
  // println("offset", offset.h, offset.w);
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      CMYKColour cmyk = cmykImageData[y][x];
      cmykPrintPolarDots(x, y, offset, radius, scale, ink, cmyk);
    }
  }
}

void cmykPrintPolarDots(int x, int y, Dimension offset, float radius, float scale, String ink, CMYKColour cmyk) {
  final float step = 60;
  color dotColour = getRGBfromInk(ink);
  float intensity = cmyk.getInkIntensity(ink);
  float start = getScreenAngle(ink);
  float end = map(intensity, 0, 1, 0, 360 * (radius - 1));
  // if (x == 0 && y == 0) {
  //   println(x, y, radius, scale, ink, cmyk, start, nf(intensity, 0, 2), nf(step, 0, 2));
  // }
  int count = 0;
  for (float angle = start; angle < end; angle += step) {
    if (++count > 360 / (int)step) {
      count = 1;
      radius--;
    }
    float rad = radians(angle);
    //add some jiggle
    float randomX = random(-0.2, 0.2) * radius;
    float randomY = random(-0.2, 0.2) * radius;
    //calculate the polar array of points
    float xA = x * scale + offset.w + radius * cos(rad) + randomX;
    float yA = y * scale + offset.h + radius * sin(rad) + randomY;
    outputPicture.set(round(xA), round(yA), dotColour);
  }
}

int mapInkToIndex(String ink) {
  return mapInkIndex.getInt(ink);
}

class Dimension {
  int w;
  int h;

  Dimension(int w, int h) {
    this.w = w;
    this.h = h;
  }

  Dimension(float w, float h) {
    this.w = floor(w);
    this.h = floor(h);
  }
}

class fpPoint {
  float x;
  float y;

  fpPoint(float x, float y) {
    this.x = x;
    this.y = y;
  }
}
