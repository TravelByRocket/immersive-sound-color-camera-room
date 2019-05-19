
//**********************************************************************
// Program name      : .pde
// Author            : Bryan Costanza (GitHub: TravelByRocket)
// Date created      : 20190511
// Purpose           : 
// Revision History  : 
// 20190511 --  
//**********************************************************************

import processing.sound.*;

////////////////////////////////////////
// START EASY-ACCESS VARIABLE AREA
////////////////////////////////////////

int microphoneSelected = 1; //enter the list number of the microphone you want to use
int scaleFactor = 3; // lower numbers require louder volumes to trigger; top of screen is always trigger point 
String gradientFilename = "colorGradient01.png";

////////////////////////////////////////
// END EASY-ACCESS VARIABLE AREA
////////////////////////////////////////

// SOUND AND RELATED VARIABLES

int bands = 2048; // number of fequency bands; must be a power of 2
float[] spectrumCurrent = new float[bands];
float[] spectrumFiltered = new float[bands];
float lowPassWeightBar = 0.9;
float lowPassWeightEllipse = 0.80;


int valueGain = scaleFactor; // 1000 appropriate for testing in a coffee shop; lower values need higher volume
// light whistle has a raw value of about 0.02 and this need to be scales up since the HSV scales are out of 100

float maxSpectrumFilteredCurrent;
float maxSpectrumFilteredAverage;
float maxSpectrumFilteredIndexCurrent;
float maxSpectrumFilteredIndexAverage;

PImage colorGradient;

void settings() {	
  //size(600,600);
  fullScreen();
}

color peakColor;
void setup() {
  background(40);
  colorMode(HSB,360,100,100);
  soundSetup(); // grouping of sound setup tasks
  colorGradient = loadImage(gradientFilename);
  peakColor = color(200); //just initialize for first draw loop
}

int bandsToShow = 270;

float peakHue;
float peakSat;
float peakVal;
void draw() {
  background(peakColor);
  
  // ANALYZE AND DRAW SPECTRUM
  fft.analyze(spectrumCurrent); // perform FFT and save to spectrumCurrent
  for(int i = 0; i < bandsToShow; i++){ // for each frequency band, limited to human vocal range 
    spectrumFiltered[i] = spectrumFiltered[i]*lowPassWeightBar+spectrumCurrent[i]*((1-lowPassWeightBar)*(pow(bandsToShow-i,0.5))); // filter the FFT results
    stroke(0);
    fill(colorGradient.get((int)map(i,0,bandsToShow,0,colorGradient.width),25)); //bar color
    //line(i,height,i,height - spectrumFiltered[i]*height*scaleFactor); // draw a vertical line from the bottom of the screen indicating the power in each band
    float x0 = map(i  ,0,bandsToShow,0,width);
    float x1 = map(i+1,0,bandsToShow,0,width);
    rectMode(CORNERS);
    rect(x0,height,x1,height - spectrumFiltered[i]*height*scaleFactor-1); // draw a vertical bar from the bottom of the screen indicating the power in each band; remove px (make it taller on a -Y axis) to make it a little more visible
    //stroke(280,100,100); // use a purple stroke for points drawn below
    //float x3 = map(i+0.5,0,bandsToShow,0,width);
    //point(x3,height - spectrumCurrent[i]*height*scaleFactor); // draw instantaneous value of each frequency band 
  }
  
  
  // PREPARE FOR BOX AND IMAGE DRAWING
  imageMode(CENTER);
  noStroke();
  
  // GET VALUE AND INDEX OF LOUDEST SPECTRUM BAND
  maxSpectrumFilteredCurrent = max(spectrumFiltered);
  for (int j = 0; j < bands; j++) {
    if (maxSpectrumFilteredCurrent == spectrumFiltered[j]){
      maxSpectrumFilteredIndexCurrent = j;
    }
  }

  // DRAW A LOWPASS-CONTROLLED ELLIPSE AT THE PEAK
  maxSpectrumFilteredIndexAverage = maxSpectrumFilteredIndexAverage*lowPassWeightEllipse+maxSpectrumFilteredIndexCurrent*(1-lowPassWeightEllipse);
  maxSpectrumFilteredAverage = maxSpectrumFilteredAverage*lowPassWeightEllipse/2+maxSpectrumFilteredCurrent*(1-lowPassWeightEllipse/2); // dividing by two improves vertical responsiveness
  stroke(0);
  peakColor = colorGradient.get((int)map(maxSpectrumFilteredIndexAverage,0,bandsToShow,0,colorGradient.width),25);
  peakHue = hue(peakColor);
  peakSat = saturation(peakColor);
  peakVal = brightness(peakColor);
  fill(peakColor);
  ellipseMode(CENTER);
  float x2 = map(maxSpectrumFilteredIndexAverage+0.5,0,bandsToShow,0,width); // add 0.5 (half and index) to get to center of frequency box
  ellipse(x2,height - maxSpectrumFilteredAverage*height*scaleFactor-10,30,30);
}

// SOUND SETUP
Sound s;
FFT fft;
AudioIn in;
void soundSetup(){
  s = new Sound(this); // create sound object s
  s.inputDevice(microphoneSelected); // collect sound from specified input device

  // Create an Input stream which is routed into the Amplitude analyzer
  fft = new FFT(this, bands); // get the first audio input channel from sound device
  in = new AudioIn(this, 0); // 1 also works; is this L/R audio?; 0 is default and the second parameter is optional anyway
  in.start(); // start the Audio Input
  fft.input(in); // patch the AudioIn
}

void keyPressed() {
  if (key == 's') { // press 's' to display sound (audio) devices
    Sound.list(); // prints list of sound devices
  } else if (key == 'e' || key == 'q') { // q or e buttons to stop
    exit();
  }
}
