//**********************************************************************
// Program name      : .pde
// Author            : Bryan Costanza (GitHub: TravelByRocket)
// Date created      : 20190511
// Purpose           : 
// Revision History  : 
// 20190511 --  
//**********************************************************************

import processing.sound.*;
import processing.video.*;

// SOUND AND RELATED VARIABLES
Sound s;
FFT fft;
AudioIn in;
int bands = 512; // number of fequency bands; must be a power of 2
float[] spectrumCurrent = new float[bands];
float[] spectrumFiltered = new float[bands];
float lowPassWeightBar = 0.97;
float lowPassWeightEllipse = 0.80;

int scaleFactor = 50; // for vertical bar drawing
int valueGain = 1000; // 1000 appropriate for testing in a coffee shop; lower values need higher volume
// light whistle has a raw value of about 0.02 and this need to be scales up since the HSV scales are out of 100

float maxSpectrumFilteredCurrent;
float maxSpectrumFilteredAverage;
float maxSpectrumFilteredIndexCurrent;
float maxSpectrumFilteredIndexAverage;

// VIDEO AND RELATED VARIABLES
Capture cam;
boolean recordMode = false;
int recordStartFrame = -5000; // set well before start of running so there is not a dead time at the beginning
PGraphics offScreenVid;

void settings() {	
  size(600,600);
}

void setup() {
  frameRate(30);
	background(40);
	Sound.list();
  s = new Sound(this);
  s.inputDevice(1);

  // Create an Input stream which is routed into the Amplitude analyzer
  fft = new FFT(this, bands);
  // get the first audio input channel from sound device
  in = new AudioIn(this, 0);
  // start the Audio Input
  in.start();
  // patch the AudioIn
  fft.input(in);
  // VIDEO SETUP
  String[] cameras = Capture.list();

  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(cameras[i]);
    }
    
    // The camera can be initialized directly using an 
    // element from the array returned by list():
    cam = new Capture(this, cameras[0]);
    cam.start();   
  }  

  // OTHER SETUP
  colorMode(HSB,100);
  offScreenVid = createGraphics(1280, 720);
}

void draw() {
  background(40); // dark gray background
  fft.analyze(spectrumCurrent); // perform FFT and save to spectrumCurrent
  
  for(int i = 0; i < bands; i++){
    // The result of the FFT is normalized
    // draw the line for frequency band i scaling it up.
    spectrumFiltered[i] = spectrumFiltered[i]*lowPassWeightBar+spectrumCurrent[i]*(1-lowPassWeightBar); // filter the results
    stroke(i%100,100,100);
    line(i,height,i,height - spectrumFiltered[i]*height*scaleFactor);
    stroke(40,100,100);
    point(i,height - spectrumCurrent[i]*height*scaleFactor);
  }

  rectMode(CORNERS);
  fill(maxSpectrumFilteredIndexAverage%100,100,100);
  rect(0,0,width/2, height*0.66);
  fill(maxSpectrumFilteredIndexAverage%100, 100, maxSpectrumFilteredAverage*valueGain);
  rect(width/2,0,width, height*0.66);
  
  // SHOW CAMERA IMAGES
  if (cam.available() == true) {
    cam.read();
  }
  imageMode(CENTER);
  tint(maxSpectrumFilteredIndexAverage%100, 100, 100);
  image(cam,width/4,height/3,1280/6,720/6);
  //println("maxSpectrumAverageAverage*valueGain: "+maxSpectrumAverageAverage*valueGain);
  if(maxSpectrumFilteredAverage*valueGain > 10 && recordMode == false && frameCount-recordStartFrame > 60*5){ 
    // if it is loud enough, and if it is not already recording, and it has been 5 seconds since the last recordStart
    recordMode = true;
    recordStartFrame = frameCount;
  } else if (recordMode == true && frameCount-recordStartFrame > 60*3) { // if it has been recording for about 3 seconds
    recordMode = false; // then stop the recording
  }
  
  if(recordMode){
    tint(maxSpectrumFilteredIndexAverage%100, 100, 100);
    image(cam,width*3/4,height/3,1280/6,720/6);
  }
  
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
  fill(maxSpectrumFilteredIndexAverage%100,100,100);
  ellipseMode(CENTER);
  ellipse(maxSpectrumFilteredIndexAverage,height - maxSpectrumFilteredAverage*height*scaleFactor,10,10);

  // PRINT FRAMERATE
  fill(0);
  textSize(16);
  textAlign(RIGHT,BOTTOM);
  text(round(frameRate)+" fps ",height,width);
}
