/**
 * ImageSplitCMYK
 * 1. draw the input image
 * 2. sum colour components into a smaller picture at a given spacing
 * 3. convert the smaller pictures into CMYK separations
 * 4. draw the polar rotations
 * 5. save to a PDF
 */

import processing.pdf.*;

String inputFile = "";
final static int minGridSpacing = 2;
final static int maxGridSpacing = 32;
int gridSpacing = 5;
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
int lastWidth;
int lastHeight;
boolean doRedraw = false;
CMYKColour[][] cmykImageData;
final static int WAIT = 0;
final static int REQUIRED = 1;
final static int RUNNING = 2;
final static int DONE = 3;
int statusReadFile = WAIT;
int statusInitComponentImages = WAIT;
int statusSumColourComponents = WAIT;
int statusCMYKExtraction = WAIT;
int statusCreatePrint = WAIT;
int statusSavePrint = WAIT;

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
  Point dim = new Point(floor(inputPicture.width / gridSpacing), floor(inputPicture.height / gridSpacing));
  cmykImageData = new CMYKColour[dim.y][dim.x];
  smallPictureRed = createImage(dim.x, dim.y, RGB);
  smallPictureGreen = createImage(dim.x, dim.y, RGB);
  smallPictureBlue = createImage(dim.x, dim.y, RGB);
  smallPictureCyan = createImage(dim.x, dim.y, RGB);
  smallPictureMagenta = createImage(dim.x, dim.y, RGB);
  smallPictureYellow = createImage(dim.x, dim.y, RGB);
  smallPictureBlack = createImage(dim.x, dim.y, RGB);
  outputPicture = createImage(1, 1, RGB); // an initial pixel then set white and resize to that of the paper
  outputPicture.set(0, 0, #FFFFFF);
  Point dimOutput = scaleDimensionIgnoreOrientation(inputPicture.width, inputPicture.height, longEdgeDots, shortEdgeDots);
  outputPicture.resize(dimOutput.x, dimOutput.y);
  doRedraw = true;
  statusInitComponentImages = DONE;
  statusSumColourComponents = REQUIRED;
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
  for (int y = 0; y < smallPictureRed.height; y++) {
    for (int x = 0; x < smallPictureRed.width; x++) {
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
  int y = 0;
  int x = 0;
  float scale = (float)outputPicture.width / smallPictureRed.width;
  float radius = ((float)outputPicture.width / smallPictureRed.width * gridSpacing) / 2;
  for (; y < smallPictureRed.height; y++) {
    for (x = 0; x < smallPictureRed.width; x++) {
      CMYKColour cmyk = cmykImageData[y][x];
      cmykPrintingDots(x, y, radius, scale, cmyk, "c");
      cmykPrintingDots(x, y, radius, scale, cmyk, "m");
      cmykPrintingDots(x, y, radius, scale, cmyk, "y");
      cmykPrintingDots(x, y, radius, scale, cmyk, "k");
    }
  }
  doRedraw = true;
  statusCreatePrint = DONE;
}

void savePrint() {
  statusSavePrint = RUNNING;
  String basename = inputFile.substring(0, inputFile.indexOf(".jpg"));
  String pdfSaveFile = "output_" + basename + ".pdf";
  PGraphics pdf = createGraphics(outputPicture.width, outputPicture.height, PDF, pdfSaveFile);
  pdf.beginDraw();
  pdf.image(outputPicture, 0, 0);
  pdf.dispose();
  pdf.endDraw();
  println("Saved to " + pdfSaveFile);
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

void cmykPrintingDots(int x, int y, float radius, float scale, CMYKColour cmyk, String ink) {
  color dotColour = getRGBfromInk(ink);
  float sAng = getScreenAngle(ink);
  float intensity = cmyk.getInkIntensity(ink);
  float step = map(intensity, 1.0, 0.0, 7.2, 72);
  for (float aAng = sAng; aAng <= 360 + sAng; aAng += step) {
    float aRad = radians(aAng);
    //add some jiggle
    float aRandomX = random(-0.1, 0.1) * radius;
    float aRandomY = random(-0.1, 0.1) * radius;
    //calculate the polar array of points
    float xA = x * scale + radius * (1 + cos(aRad)) + aRandomX;
    float yA = y * scale + radius * (1 + sin(aRad)) + aRandomY;
    outputPicture.set(round(xA), round(yA), dotColour);
  }
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

Point scaleDimensionIgnoreOrientation(int srcX, int srcY, int targetLong, int targetShort) {
  int inLong = max(srcX, srcY);
  int inShort = min(srcX, srcY);
  float scale1 = (float)targetLong / inLong;
  float scale2 = (float)targetShort / inShort;
  if (scale1 <= scale2) {
    return new Point(round(scale1 * srcX), round(scale1 * srcY));
  } else {
    return new Point(round(scale2 * srcX), round(scale2 * srcY));
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

