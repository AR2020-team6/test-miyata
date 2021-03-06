import gab.opencv.*;
import processing.video.*;

final boolean MARKER_TRACKER_DEBUG = true;
final boolean BALL_DEBUG = true;

final boolean USE_SAMPLE_IMAGE = true;

// We've found that some Windows build-in cameras (e.g. Microsoft Surface)
// cannot work with processing.video.Capture.*.
// Instead we use DirectShow Library to launch these cameras.
final boolean USE_DIRECTSHOW = true;


// final double kMarkerSize = 0.036; // [m]
final double kMarkerSize = 0.024; // [m]

Capture cap;
DCapture dcap;
OpenCV opencv;

PShape blueEyes;

// Variables for Homework 6 (2020/6/10)
// **************************************************************
float fov = 45; // for camera capture

// Marker codes to draw snowmans
// final int[] towardsList = {0x1228, 0x0690};
// int towards = 0x1228; // the target marker that the ball flies towards
int towardscnt = 0;   // if ball reached, +1 to change the target

//final int[] towardsList = {0x005A, 0x0272};
// 0x1228 most right
// 0x1c44  most left
final int[] towardsList = {0x1c44, 0x1228};

// int towards = 0x005A;
int towards = 0x1c44;

final float GA = 9.80665;

PVector snowmanLookVector;
PVector ballPos;
float ballAngle = 25;
float ballspeed = 0;

int ballTotalFrame = 10;
final float snowmanSize = 0.010;
int frameCnt = 0;

HashMap<Integer, PMatrix3D> markerPoseMap;

MarkerTracker markerTracker;
PImage img;

KeyState keyState;

void selectCamera() {
  String[] cameras = Capture.list();

  if (cameras == null) {
    println("Failed to retrieve the list of available cameras, will try the default");
    cap = new Capture(this, 640, 480);
  } else if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {
    println("Available cameras:");
    printArray(cameras);

    // The camera can be initialized directly using an element
    // from the array returned by list():
    //cap = new Capture(this, cameras[5]);

    // Or, the settings can be defined based on the text in the list
    cap = new Capture(this, 1280, 720, "USB2.0 HD UVC WebCam", 30);
  }
}

void settings() {
  if (USE_SAMPLE_IMAGE) {
    // Here we introduced a new test image in Lecture 6 (20/05/27)
    size(1280, 720, P3D);
    //opencv = new OpenCV(this, "./marker_test2.jpg");
    opencv = new OpenCV(this, "./marker_test2.jpg");
    // size(1000, 730, P3D);
    // opencv = new OpenCV(this, "./marker_test.jpg");
  } else {
    if (USE_DIRECTSHOW) {
      dcap = new DCapture();
      size(dcap.width, dcap.height, P3D);
      opencv = new OpenCV(this, dcap.width, dcap.height);
    } else {
      selectCamera();
      size(cap.width, cap.height, P3D);
      opencv = new OpenCV(this, cap.width, cap.height);
    }
  }
}

void setup() {
  background(0);
  smooth();
  // frameRate(10);

  markerTracker = new MarkerTracker(kMarkerSize);

  if (!USE_DIRECTSHOW)
    cap.start();

  // Added on Homework 6 (2020/6/10)
  // Align the camera coordinate system with the world coordinate system
  // (cf. drawSnowman.pde)
  PMatrix3D cameraMat = ((PGraphicsOpenGL)g).camera;
  cameraMat.reset();

  keyState = new KeyState();

  // Added on Homework 6 (2020/6/10)
  ballPos = new PVector();  // ball position
  markerPoseMap = new HashMap<Integer, PMatrix3D>();  // hashmap (code, pose)
  
  blueEyes = loadShape("BlueEyes/BlueEyes.obj");
  blueEyes.scale(0.0005);
  blueEyes.rotateX(3.14/2*3);
}


void draw() {
  ArrayList<Marker> markers = new ArrayList<Marker>();
  markerPoseMap.clear();

  if (!USE_SAMPLE_IMAGE) {
    if (USE_DIRECTSHOW) {
      img = dcap.updateImage();
      opencv.loadImage(img);
    } else {
      if (cap.width <= 0 || cap.height <= 0) {
        println("Incorrect capture data. continue");
        return;
      }
      opencv.loadImage(cap);
    }
  }


  // Your Code for Homework 6 (20/06/03) - Start
  // **********************************************

  // use orthographic camera to draw images and debug lines
  // translate matrix to image center
  ortho();
  pushMatrix();
    translate(-width/2, -height/2,-(height/2)/tan(radians(fov)));
    markerTracker.findMarker(markers);
  popMatrix();

  // use perspective camera
  perspective(radians(fov), float(width)/float(height), 0.01, 1000.0);

  // setup light
  // (cf. drawSnowman.pde)
  ambientLight(180, 180, 180);
  directionalLight(180, 150, 120, 0, 1, 0);
  lights();

  // for each marker, put (code, matrix) on hashmap 
  for (int i = 0; i < markers.size(); i++) {
    Marker m = markers.get(i);
    markerPoseMap.put(m.code, m.pose);
  }

  // The snowmen face each other
  for (int i = 0; i < 2; i++) {
    PMatrix3D pose_this = markerPoseMap.get(towardsList[i]);
    PMatrix3D pose_look = markerPoseMap.get(towardsList[(i+1)%2]);

    if (pose_this == null || pose_look == null)
      break;

    float angle = rotateToMarker(pose_this, pose_look, towardsList[i]);

    
    pushMatrix();
      applyMatrix(pose_this);
      rotateZ(angle-HALF_PI);
      shape(blueEyes);
    popMatrix();

    pushMatrix();
      // apply matrix (cf. drawSnowman.pde)
      applyMatrix(pose_this);
      rotateZ(angle);
      // draw snowman
      // drawSnowman(snowmanSize);

      // move ball
      if (towardsList[i] == towards) {
        pushMatrix();
          PVector relativeVector = new PVector();
          relativeVector.x = pose_look.m03 - pose_this.m03;
          relativeVector.y = pose_look.m13 - pose_this.m13;
          float relativeLen = relativeVector.mag();

          ballspeed = sqrt(GA * relativeLen / sin(radians(ballAngle) * 2));
          ballPos.x = frameCnt * relativeLen / ballTotalFrame;

          float z_quad = GA * pow(ballPos.x, 2) / (2 * pow(ballspeed, 2) * pow(cos(radians(ballAngle)), 2));
          ballPos.z = -tan(radians(ballAngle)) * ballPos.x + z_quad;
          frameCnt++;

          if (BALL_DEBUG)
            println(ballPos, tan(radians(ballAngle)) * ballPos.x,  z_quad);

          // for (int b =0;b<100;b++){
          //   pushMatrix();
          //     float position = random(0,1);
          //     translate(ballPos.x+position*0.01, ballPos.y+position*0.01, ballPos.z - 0.025+position*0.1);
          //     noStroke();
          //     float ballcolor = random(10, 70);
          //     fill(255, ballcolor, 0);
          //     box(0.001);
          //   popMatrix();
          // }
          pushMatrix();
            translate(ballPos.x, ballPos.y, ballPos.z - 0.025);
            noStroke();
            fill(255, 255, 0);
            sphere(0.003);
          popMatrix();
          

          if (frameCnt == ballTotalFrame) {
            ballPos = new PVector();
            towardscnt++;
            towards = towardsList[towardscnt % 2];
            ballAngle = random(20, 70);
            frameCnt = 0;

            if (BALL_DEBUG)
              println("towards:", hex(towards));
          }
        popMatrix();
      }

      noFill();
      strokeWeight(3);
      stroke(255, 0, 0);
      line(0, 0, 0, 0.02, 0, 0); // draw x-axis
      stroke(0, 255, 0);
      line(0, 0, 0, 0, 0.02, 0); // draw y-axis
      stroke(0, 0, 255);
      line(0, 0, 0, 0, 0, 0.02); // draw z-axis
    popMatrix();
  }
  // Your Code for Homework 6 (20/06/03) - End
  // **********************************************

  noLights();
  keyState.getKeyEvent();

  System.gc();
}


void captureEvent(Capture c) {
  PGraphics3D g;
  if (!USE_DIRECTSHOW && c.available())
      c.read();
}

float rotateToMarker(PMatrix3D thisMarker, PMatrix3D lookAtMarker, int markernumber) {
  PVector relativeVector = new PVector();
  relativeVector.x = lookAtMarker.m03 - thisMarker.m03;
  relativeVector.y = lookAtMarker.m13 - thisMarker.m13;
  relativeVector.z = lookAtMarker.m23 - thisMarker.m23;
  float relativeLen = relativeVector.mag();

  relativeVector.normalize();

  float[] defaultLook = {1, 0, 0, 0};
  snowmanLookVector = new PVector();
  snowmanLookVector.x = thisMarker.m00 * defaultLook[0];
  snowmanLookVector.y = thisMarker.m10 * defaultLook[0];
  snowmanLookVector.z = thisMarker.m20 * defaultLook[0];

  snowmanLookVector.normalize();

  float angle = PVector.angleBetween(relativeVector, snowmanLookVector);
  if (relativeVector.x * snowmanLookVector.y - relativeVector.y * snowmanLookVector.x < 0)
    angle *= -1;

  return angle;
}
