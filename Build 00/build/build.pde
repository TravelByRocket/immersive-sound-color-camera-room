
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

import ddf.minim.*;

import java.io.FileWriter;
import java.io.*;

////////////////////////////////////////
// START EASY-ACCESS VARIABLE AREA
////////////////////////////////////////

int cameraSelected = 19; // enter the number of the list number of camera you want to use; on May 19, 2019 chose 960x540 at 15 fps 
int microphoneSelected = 1; //enter the list number of the microphone you want to use
int scaleFactor = 3; // lower numbers require louder volumes to trigger; top of screen is always trigger point 
float imageScaling = 1.4; // increase to take up more of the screen with live and replay images
float secondsToCapture = 5; // 
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

// VIDEO AND RELATED VARIABLES
Capture cam;
boolean recording = false; // save images to arraylist only for a set period of time
boolean writingToDisc = false; // focus on saving to disc
boolean replaying = false;
int recordStartFrame = -5000; // set well before start of running so there is not a dead time at the beginning
PGraphics offScreenVid;
int countCaptured = 0; // used to count saved frame number for filenames
int countWritten = 0; // used to count saved frame number for filenames
ArrayList<PImage> images = new ArrayList<PImage>();
int numFramesPerClip = 15;
String timeStamp;
int expectedFrameRate = 15;
int framesToCapture = (int)secondsToCapture*expectedFrameRate;
PImage colorGradient;

void settings() {	
  //size(600,600);
  fullScreen();
}

color peakColor;
void setup() {
  frameRate(30);
	background(40);
  colorMode(HSB,360,100,100);
  soundSetup(); // grouping of sound setup tasks
  minimSetup(); // grouping of minim setup tasks
	videoSetup(); // grouping of video/camera setup tasks
  colorGradient = loadImage(gradientFilename);
  peakColor = color(200); //just initialize for first draw loop
}

int replayCount = 0;
int bandsToShow = 270;

float peakHue;
float peakSat;
float peakVal;
void draw() {
  //background(maxSpectrumFilteredIndexAverage%360, 100, maxSpectrumFilteredAverage*valueGain*20);
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
  
  // MANAGE RECORDING AND WRITINGTODISC
  if(loudEnough() && waitEnough()){ 
    triggerRecordActions(); // moving to function so it can also be triggered by keypress
  }
  if (writingToDisc == true && images.size() == 0){
    writingToDisc = false;
    countWritten = 0; // reset for next capture and write session
  }
  
  // PREPARE FOR BOX AND IMAGE DRAWING
  imageMode(CENTER);
  noStroke();
  
  // OBTAIN CAMERA IMAGE
  if (cam.available() == true) {
    cam.read();
  }
  
  // LIVE TRIGGERED VIDEO
  if(recording && images.size() > 0){
    PImage liveImage = images.get(images.size()-1);
    image(liveImage,width/2,height/2,liveImage.width*imageScaling,liveImage.height*imageScaling);
    noStroke();
    fill(0,75);
    rectMode(CENTER);
    rect(width/2,height/20,width*(((float)(framesToCapture-images.size()+20))/(framesToCapture+20)),height/10);
    fill(0,0,100);
    textAlign(CENTER,CENTER);
    textSize(70);
    text("Time Left",width/2,height/20);
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
  peakColor = colorGradient.get((int)map(maxSpectrumFilteredIndexAverage,0,bandsToShow,0,colorGradient.width),25);
  peakHue = hue(peakColor);
  peakSat = saturation(peakColor);
  peakVal = brightness(peakColor);
  fill(peakColor);
  ellipseMode(CENTER);
  float x2 = map(maxSpectrumFilteredIndexAverage+0.5,0,bandsToShow,0,width); // add 0.5 (half and index) to get to center of frequency box
  ellipse(x2,height - maxSpectrumFilteredAverage*height*scaleFactor-10,30,30);
  
  // REPLAY VIDEO AFTER RECORDING
  if (replaying){
    PImage replayImage = images.get(replayCount); 
    image(replayImage,width/2,height/2,replayImage.width*imageScaling,replayImage.height*imageScaling);
    replayCount++;
    if (frameCount % 20 < 14) {
      fill(0,100,100);
      textAlign(CENTER,CENTER);
      textSize(70);
      text("REPLAY",width/2,height*1/3);
    }
    if (replayCount == framesToCapture){
      replayCount = 0;
      replaying = false;
      writingToDisc = true;
    }
  }
  
  // SAVE IMAGES FROM ARRAYLIST TO DISC
  if (writingToDisc){
    noStroke();
    fill(0,75);
    rectMode(CENTER);
    rect(width/2,height/20,width*(((float)images.size()+20)/(framesToCapture+20)),height/10);
    fill(255);
    textSize(70);
    textAlign(CENTER,CENTER);
    text("Aligning the Stars",width/2,height/20);
    if (images.size() > 0) { // good candidate for running on another thread
      images.get(0).save("data/capture_time"+timeStamp+"_count"+nf(countWritten,3)+".jpg");
      images.remove(0);
      countWritten++; // this gets reset in reading and writingtodisc management section
    }
  }
  
  //// DRAW FRAMERATE
  //fill(0);
  //textSize(16);
  //textAlign(RIGHT,BOTTOM);
  //text(round(frameRate)+" fps ",height,width);
}

// SOUND SETUP
Sound s;
FFT fft;
AudioIn in;
AudioInput inMinim;
void soundSetup(){
  s = new Sound(this); // create sound object s
  s.inputDevice(microphoneSelected); // collect sound from specified input device

  // Create an Input stream which is routed into the Amplitude analyzer
  fft = new FFT(this, bands); // get the first audio input channel from sound device
  in = new AudioIn(this, 0); // 1 also works; is this L/R audio?; 0 is default and the second parameter is optional anyway
  in.start(); // start the Audio Input
  fft.input(in); // patch the AudioIn
}

// MINM SETUP
Minim minim; // from minim (duh)
AudioRecorder recorder; // from minim
void minimSetup() {
  minim = new Minim(this);
  inMinim = minim.getLineIn();
}

String[] cameras;
void videoSetup(){
  cameras = Capture.list();
  
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  }
  cam = new Capture(this, cameras[cameraSelected]);
  cam.start();
}

void triggerRecordActions() {
  timeStamp = nf(hour(),2)+"h"+nf(minute(),2)+"m"+nf(second(),2)+"s";
  prepareWavFile();
  recorder.beginRecord(); // for minim
  recording = true;
  recordStartFrame = frameCount; // set a new reference for when the recording started
  bashSetup();
}

boolean loudEnough() { // used by sound trigger and key trigger
  return maxSpectrumFilteredAverage*height*valueGain > height; // triggers the recording when filtered volume exceeds value
}

boolean waitEnough(){ // used by sound trigger and key trigger
  return !recording && !writingToDisc && !replaying; // to prevent continuous triggering and time for saving to disc
}

void keyPressed() {
  if (key == 't') {
    if (recording == false && waitEnough()){ // match the sound-triggered gating in recording and writing management section...
    // ...but without sound trigger because that is why it is being assigned to a keypress
      triggerRecordActions();
    }
  } else if (key == 'v') { // press 'v' to display video (camera) devices
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println("["+i+"] "+cameras[i]);
    }
  } else if (key == 's') { // press 's' to display sound (audio) devices
    Sound.list(); // prints list of sound devices
  } else if (key == 'e' || key == 'q') { // q or e buttons to stop
    exit();
  }
}

void captureEvent (Capture c) {
  if(recording){
    c.read();
    images.add(c.get());
    countCaptured++;
    filterMagic();
  }
  if (countCaptured >= framesToCapture){
    countCaptured = 0; // reset for next run
    recording = false; // stop saving images, stop saving audio
    replaying = true; // start writing images and audio to disc
    recorder.endRecord();
  }
}

void prepareWavFile(){
  recorder = minim.createRecorder(inMinim, "data/captureaudio_"+timeStamp+".wav"); // for minim; this will override
}

// trigger the bashSetup() function when the timeStamp is created
// guidance from https://forum.processing.org/two/discussion/11883/how-to-append-a-text-to-a-file 
void bashSetup() { // would make most sense to trigger after recording but it is a fast operation 
  try {
    File bashScriptFile = new File(sketchPath()+"/data/makeVideosFFMPEG.sh");
    
    if (!bashScriptFile.exists()) {
      bashScriptFile.createNewFile();
    }
 
    FileWriter fw = new FileWriter(bashScriptFile, true);///true = append
    BufferedWriter bw = new BufferedWriter(fw);
    
    PrintWriter pw = new PrintWriter(bw);
    
    pw.write("ffmpeg -thread_queue_size 512 -r 15 -f image2 -s 1280x720 -i capture_time"+timeStamp+
      "_count%03d.jpg -i captureaudio_"+timeStamp+
      ".wav -vcodec libx264 -crf 25  -pix_fmt yuv420p video_"+timeStamp+".mp4\n");
    
    pw.close();
  } catch(IOException ioe) {
    System.out.println("Exception ");
    ioe.printStackTrace();
  }
}

void filterMagic(){
    PImage modImage = images.get(images.size()-1);
    modImage.loadPixels();
    //tint(peakHue,100,100);
    //for (int k = 0; k < modImage.width*modImage.height; k++){ // this causes many kinds of memory issues
      //int bandSat = (int)saturation(modImage.pixels[k]);
      //int bandVal = (int)brightness(modImage.pixels[k]);
      //modImage.pixels[k] = color(100,100,100);
    //}
    
    for (int i = 0; i < bandsToShow; i++){
      int startIndex = (int)random(modImage.width*modImage.height);
      for (int j = startIndex; j < constrain(startIndex+spectrumFiltered[i]*height*scaleFactor*2.5,0,modImage.width*modImage.height-1); j++){
        modImage.pixels[j] = color(colorGradient.get((int)map(i,0,bandsToShow,0,colorGradient.width),25));
      }
    }
    modImage.updatePixels();
}
