//**********************************************************************
// Program name      : .pde
// Author            : Bryan Costanza (GitHub: TravelByRocket)
// Date created      : 20190511
// Purpose           : 
// Revision History  : 
// 20190511 --  
//**********************************************************************

import processing.sound.*;

Sound s;
FFT fft;
AudioIn in;
int bands = 512; // number of fequency bands; must be a power of 2
float[] spectrumCurrent = new float[bands];
float[] spectrumAverage = new float[bands];
float lowPassWeightBar = 0.97;
float lowPassWeightEllipse = 0.90;

int scaleFactor = 50; // for vertical bar drawing
int valueGain = 1000; // 1000 appropriate for testing in a coffee shop; lower values need higher volume
// light whistle has a raw value of about 0.02 and this need to be scales up since the HSV scales are out of 100

float maxSpectrumAverageCurrent;
float maxSpectrumAverageAverage;
float maxSpectrumAverageIndexCurrent;
float maxSpectrumAverageIndexAverage;

void settings() {
	size(600,600);
}

void setup() {
	background(40);

	Sound.list();

  s = new Sound(this);
  s.inputDevice(1);

  // println(s.sampleRate()); print sample rate, default is 44100

  // Create an Input stream which is routed into the Amplitude analyzer
  fft = new FFT(this, bands);
  // get the first audio input channel from sound device
  in = new AudioIn(this, 0);
  
  // start the Audio Input
  in.start();
  
  // patch the AudioIn
  fft.input(in);

  colorMode(HSB,100);
}

void draw() {
  background(40); // dark gray background
	fft.analyze(spectrumCurrent); // perform FFT and save to spetrumCurrent

	for(int i = 0; i < bands; i++){
	  // The result of the FFT is normalized
	  // draw the line for frequency band i scaling it up.
		spectrumAverage[i] = spectrumAverage[i]*lowPassWeightBar+spectrumCurrent[i]*(1-lowPassWeightBar);
	  stroke(i%100,100,100);
	  line(i,height,i,height - spectrumAverage[i]*height*scaleFactor);
	  stroke(40,100,100);
	  point(i,height - spectrumCurrent[i]*height*scaleFactor);

  }

  // GET VALUE AND INDEX OF LOUDEST SPECTRUM BAND
  maxSpectrumAverageCurrent = max(spectrumAverage);
  for (int j = 0; j < bands; j++) {
    if (maxSpectrumAverageCurrent == spectrumAverage[j]){
      maxSpectrumAverageIndexCurrent = j;
    }
  }

  // DRAW A LOWPASS-CONTROLLED ELLIPSE AT THE PEAK
  maxSpectrumAverageIndexAverage = maxSpectrumAverageIndexAverage*lowPassWeightEllipse+maxSpectrumAverageIndexCurrent*(1-lowPassWeightEllipse);
  maxSpectrumAverageAverage = maxSpectrumAverageAverage*lowPassWeightEllipse+maxSpectrumAverageCurrent*(1-lowPassWeightEllipse);
  noStroke();
  fill(maxSpectrumAverageIndexAverage%100,100,100);
  ellipseMode(CENTER);
  ellipse(maxSpectrumAverageIndexAverage,height - maxSpectrumAverageAverage*height*scaleFactor,10,10);

  rectMode(CORNERS);
  rect(0,0,width/2, height*0.66);
  fill(maxSpectrumAverageIndexAverage%100, 100, maxSpectrumAverageAverage*valueGain);
  rect(width/2,0,width, height*0.66);
}

