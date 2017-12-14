
/*
  Yún HTTP Client

 This example for the YunShield/Yún shows how create a basic
 HTTP client that connects to the internet and downloads
 content. In this case, you'll connect to the Arduino
 website and download a version of the logo as ASCII text.

 created by Tom igoe
 May 2013

 This example code is in the public domain.

 http://www.arduino.cc/en/Tutorial/HttpClient

 */

#include <Bridge.h>
#include <ArduinoJson.h>
#include <Servo.h>

enum Position { center, left, right }; //90, 45 and 135 degrees

Servo myServo;
Position currentPosition = center;
String jsonString = "";
float previousNormalizedPosition;


void setup() {
  // Bridge takes about two seconds to start up
  // it can be helpful to use the on-board LED
  // as an indicator for when it has initialized
  pinMode(13, OUTPUT);
  digitalWrite(13, LOW);
  Bridge.begin();
  digitalWrite(13, HIGH);
  myServo.attach(9);
  Serial.begin(9600);
  myServo.write(90);
  
  while (!Serial); // wait for a serial connection
}

void loop() {
  jsonString = "";
  float normalizedPosition = 0.5;

  runCurlRequest();

  StaticJsonBuffer<1000> jsonBuffer;
  JsonObject& root = jsonBuffer.parseObject(jsonString);
    
  normalizedPosition = (float) root.begin()->value;
 /* if (normalizedPosition != previousNormalizedPosition) {
    int angle;
    String message="";
    switch(currentPosition) {
     case center:
      if (normalizedPosition > 0.5) {
          angle = 45;
          currentPosition = left;
          message = "CENTER -> LEFT for position of ";
      } else if (normalizedPosition < 0.5) {
          angle = 135;
          currentPosition = right;
          message = "CENTER -> RIGHT for position of ";
      }
      break;
     case left:
      if (normalizedPosition < 0.5) {
          angle = 90;
          currentPosition = center;
           message = "LEFT -> CENTER for position of ";
      }
     break;
     case right:
      if (normalizedPosition > 0.5) {
          angle = 90;
          currentPosition = center;
          message = "RIGHT -> CENTER for position of ";
      }
     break; 
    }
    Serial.print("previous position was ");
    Serial.println(previousNormalizedPosition);
    Serial.print(message);
    Serial.println(normalizedPosition);
    myServo.write(angle);
    previousNormalizedPosition = normalizedPosition;
  }
  */

  int angle = mapf(normalizedPosition, 0.0, 1.0, 135, 45);
  myServo.write(angle);
  Serial.print("rotating to: ");
  Serial.print(angle);
  Serial.print(" from position: ");
  Serial.println(normalizedPosition);

  delay(250);

  //SerialUSB.flush();

}

double mapf(double x, double in_min, double in_max, double out_min, double out_max) {
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

void runCurlRequest() {
  // Launch "curl" command and get Arduino ascii art logo from the network
  // curl is command line program for transferring data using different internet protocols
  Process p;        // Create a process and call it "p"
  p.begin("curl");  // Process that launch the "curl" command
  p.addParameter("-k"); // Add the URL parameter to "curl"
  p.addParameter("https://stupidiphonerobot.firebaseio.com/deltas.json?orderBy=\"$key\"&limitToLast=1"); // Add the URL parameter to "curl"
  p.run();      // Run the process and wait for its termination

  // Print arduino logo over the Serial
  // A process output can be read with the stream methods
  while (p.available()>0) {
    // if there are incoming bytes available
    // from the server, read them and add them to the global json string:
    char c = p.read();
   // Serial.print(c);
    jsonString += c;
  }

  // Ensure the last bit of data is sent.
  //Serial.flush();
}
