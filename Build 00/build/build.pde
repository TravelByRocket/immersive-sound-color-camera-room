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
boolean recordMode = false; // save images to arraylist only for a set period of time
boolean writeMode = false; // focus on saving to disc
int recordStartFrame = -5000; // set well before start of running so there is not a dead time at the beginning
PGraphics offScreenVid;
int count = 0; // used to count saved frame number for filenames
ArrayList<PImage> images = new ArrayList<PImage>();
int numFramesPerClip = 15;
String timeStamp;

void settings() {	
  size(600,600);
}

void setup() {
  frameRate(30);
	background(40);
  colorMode(HSB,360,100,100);
  soundSetup(); // internal function handling sound setup operations
	videoSetup(); // "" video ""
}

void draw() {
  background(40); // dark gray background
  
  // ANALYZE AND DRAW SPECTRUM
  fft.analyze(spectrumCurrent); // perform FFT and save to spectrumCurrent
  for(int i = 0; i < bands; i++){ // for each frequency band
    spectrumFiltered[i] = spectrumFiltered[i]*lowPassWeightBar+spectrumCurrent[i]*(1-lowPassWeightBar); // filter the FFT results
    stroke(i%360,100,100); // set the stroke color going around color wheel with full Saturation and Value 
    line(i,height,i,height - spectrumFiltered[i]*height*scaleFactor); // draw a vertical line from the bottom of the screen indicating the power in each band
    stroke(280,100,100); // use a purple stroke for points drawn below
    point(i,height - spectrumCurrent[i]*height*scaleFactor); // draw instantaneous value of each frequency band 
  }

  // OBTAIN CAMERA IMAGE
  if (cam.available() == true) {
    cam.read();
  }
  
  // SAVE IMAGE TO ARRAYLIST
  if(recordMode){
    images.add(cam);
  }
  
  // MANAGE RECORDING AND WRITINGMODE
  if(maxSpectrumFilteredAverage*valueGain > 10 && recordMode == false && frameCount-recordStartFrame > 150){ 
    // if it is loud enough, and if it is not already recording, and it has been ## frames seconds since the last recordStart
    recordMode = true;
    recordStartFrame = frameCount; // set a new reference for when the recording started
    timeStamp = nf(hour(),2)+"h"+nf(minute(),2)+"m"+nf(second(),2)+"s";
  } else if (recordMode == true && frameCount-recordStartFrame >= 15) { // if it has been recording for ## frames
    recordMode = false; // then stop the recording
    writeMode = true;
    println("recordMode: "+recordMode+" at "+millis());
    println("writeMode: "+writeMode+" at "+millis());
  } else if (writeMode == true && images.size() == 0){
    writeMode = false;
    count = 0;
    println("writeMode: "+writeMode+" at "+millis());
  }
  
  // PREPARE FOR BOX AND IMAGE DRAWING
  rectMode(CORNERS);
  imageMode(CORNERS);
  noStroke();
  
  // CONTINUOUS MONITORING SECTION OF VIS
  fill(maxSpectrumFilteredIndexAverage%360,100,100); // hue determined by loudest band
  //rect(0,0,width/2, height*0.66); // left half and top two thirds
  triangle(0,0,width,0,0,height*0.66);
  tint(maxSpectrumFilteredIndexAverage%360, 100, 100);
  image(cam,width*0.05,height*0.05,width/2*0.95,height/3*0.95);
  
  // EFFECT DEVELOPMENT SECTION OF VIS
  fill(maxSpectrumFilteredIndexAverage%360, 100, maxSpectrumFilteredAverage*valueGain); // hue determined by loudest band and value from loudness of that band
  //rect(width/2,0,width, height*0.66); // right half and top two thirds
  triangle(width,0,width,height*0.66,0,height*0.66);
  if(recordMode && images.size() > 0){
    tint(maxSpectrumFilteredIndexAverage%360, 100, 100);
    //image(cam,width/2*1.05,height/3*1.05,width*0.95,height*2/3*0.95);
    image(images.get(images.size()-1),width/2*1.05,height/3*1.05,width*0.95,height*2/3*0.95);
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
  fill(maxSpectrumFilteredIndexAverage%360,100,100);
  ellipseMode(CENTER);
  ellipse(maxSpectrumFilteredIndexAverage,height - maxSpectrumFilteredAverage*height*scaleFactor,10,10);
  
  // SAVE IMAGES FROM ARRAYLIST TO DISC
  
  if (writeMode){
    fill(0,100,100);
    textSize(18);
    textAlign(CENTER,CENTER);
    text("writing data. "+nf(images.size(),3)+" frames remaining",width/2,height/2);
    //for (PImage im : images){
    if (images.size() > 0) {
      images.get(0).save("data/capture_time"+timeStamp+"_count"+nf(count,3)+".jpg");
      images.remove(0);
      count++;
    } else if (images.size() == 0){ // this doesn't trigger because handled in recording manager section
      //count = 0; // see above
    }
  }
  
  // DRAW FRAMERATE
  fill(0);
  textSize(16);
  textAlign(RIGHT,BOTTOM);
  text(round(frameRate)+" fps ",height,width);
}

void soundSetup(){
  Sound.list(); // prints list of sound devices
  s = new Sound(this); // create sound object s
  s.inputDevice(1); // collect sound from specified input device

  // Create an Input stream which is routed into the Amplitude analyzer
  fft = new FFT(this, bands);
  // get the first audio input channel from sound device
  in = new AudioIn(this, 0); // 1 also works; is this L/R audio?; 0 is default and the second parameter is optional anyway
  // start the Audio Input
  in.start();
  // patch the AudioIn
  fft.input(in); 
}

void videoSetup(){
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
}

//void captureEvent(Capture which){
//  if(recordMode){
//    images.add(cam);
//  }
//}
