import processing.video.*;
String[] cameras;
void setup() {
	cameras = Capture.list();
  for (int i = 0; i < cameras.length; i++) {
    println("["+i+"] "+cameras[i]);
  }
	exit();
}
