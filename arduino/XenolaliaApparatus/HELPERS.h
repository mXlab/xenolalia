////////////////////////
///    HELPERS       ///
////////////////////////
/*
This file contains all the function that interface with the connected hardware
for the project

  int check_liquid() 
  void pumpin()
  void pumpout()
  void ServoShake() 
  void reFresh(){
  void ServoTest() 
  void StripTest()
  void setupPins()


*/
int check_liquid() 
{
  /*
    This function verify the amount of liquid in the petridish and return an integer value representing how full it is. 
    If the liquid level is below the threshold is flashed the pixel ring green. If it is over it sets it to red
  */

  
  OSCMessage reply("/debug");
    
  int myLevel=0;
  for(int i=1; i<=20; ++i)
  {
    liquidLevel = analogRead(liquidPin);
    myLevel += liquidLevel;
    delay(10);
  }
  
  liquidLevel = int(myLevel/20);
    
  Serial.print("liquid level: ");
  Serial.println(liquidLevel);

  sprintf(buff, "dishlevel : %d | liquid Treshold : %d " ,liquidLevel , liquidThreshold);
  reply.add( buff );
  Udp.beginPacket(dest, rxport);
  reply.send(Udp);
  Udp.endPacket();
  reply.empty();
 
  if(liquidLevel < liquidThreshold)
  {

    
    strip_green();
    delay(100);
    strip_black();
  }
  else
  {
    strip_red();
    delay(100);
  }

  return liquidLevel;
}
////////////////////////////////////

void pumpin()
{
  /*
    This function control pump1 and valve1 to fill the Petri dish 
    until the liquid sensor sends a signal that it's full
  */

    OSCMessage reply("/debug");
    int dishlevel = 1;
    const int numPump{8};
    bool petriFull{false};
   
    while(petriFull == false)
    {
      
     
      for( int i{0} ; i < numPump ; i++)
      {
        dishlevel = check_liquid();
        if(dishlevel >= liquidThreshold)
        {
          petriFull = true;
          break;
        }
        digitalWrite(P1pin,HIGH);
        digitalWrite(V1pin,HIGH);
        delay(250);
        digitalWrite(P1pin,LOW);
        digitalWrite(V1pin,LOW);  
        Serial.println("dishlevel: ");
        Serial.println(dishlevel);
      }
      petriFull = true;
    reply.add( "Exceded max pump count" );
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
      
    }
    delay(500);
    reply.add( "Petridish is full" );
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
    strip_black();
}
///////////////////////////////

void pumpout()
{
  /*
    This function start pump 2 and valve 2 for 15 sec to empty the fluid 
    in the petridish
  */
      stripix(0,100,0);
      digitalWrite(P2pin,HIGH);
      digitalWrite(V2pin,HIGH);
      delay(15000);
       strip_black();
      digitalWrite(P2pin,LOW);
      digitalWrite(V2pin,LOW); 
}
///////////////////////////////

void ServoShake() 
{
  /*
    This function control the servo to perform a shake cycle to mix the euglena in the tube.
    It also sets the pixel ring the right color to indicate what's hapenning
  */

  strip_blue();
  
  for(int posDegrees = 0; posDegrees <= maxrotation; posDegrees++) 
  {
    servo1.write(posDegrees);
  //  Serial.println(posDegrees);
    delay(zpeed);
  }

  delay(restime);

  // MID SHAKE
  for(int i=1; i<=7; i++)
  {      
    strip_blue();
    for(int posDegrees = maxrotation; posDegrees >= 50; posDegrees--) 
    {        
      servo1.write(posDegrees);
       delay(zpeed);
    }
    strip_white();  
    for(int posDegrees = 50; posDegrees <= maxrotation; posDegrees++)
    {    
      servo1.write(posDegrees);
      delay(zpeed);
    }
  }
  
  strip_blue();
 
  for(int posDegrees = maxrotation; posDegrees >= 0; posDegrees--) 
  {
    servo1.write(posDegrees);
//  Serial.println(posDegrees);
    delay(zpeed);
  }

  delay(restime);
  strip_black();

}
////////////////////////////////////

void reFresh(){
  /*
    This function refresh the euglena in the petridish
    by pumping out the liquid in the tube, starting a complete
    shake cycle and pumping the liquid back in the petridish
  */   
      pumpout();
      delay(2000);
      for(int i=1; i<=2; i++) //why is this not shaketimes???
      {
         ServoShake();
      }
      delay(2000);      
//      oscUpdate();
      pumpin();
      delay(2000);
      
}
///////////////////////////////

void ServoTest() 
{
  /*
    This function performs a test cycle on the servo motor. 
    It will go from 0 to its max rotation, stop, come back to 0 and stop again.
  */
  for(int posDegrees = 0; posDegrees <= maxrotation; posDegrees++) 
  {
    servo1.write(posDegrees);
  //  Serial.println(posDegrees);
    delay(zpeed);
  }

  delay(restime);

  for(int posDegrees = maxrotation; posDegrees >= 0; posDegrees--) 
  {
    servo1.write(posDegrees);
  //  Serial.println(posDegrees);
    delay(zpeed);
  }

  delay(restime);

}
///////////////////////////////////

void read_liquid() { //NOT USED IN  THE CODE
  liquidLevel = analogRead(liquidPin);
  Serial.print("liquid level: ");
  Serial.println(liquidLevel);
}
////////////////////////////////////

void StripTest()
{
  /*
    This function test the pixel ring cycling through all the defined colors and then turns it off
  */
  strip_black();
  delay(500);
  strip_red();
  delay(500);
  strip_green();
  delay(500);
  strip_blue();
  delay(500);
  strip_white();
  delay(500);
  strip_black();  
}
///////////////////////////////

void setupPins()
{
/*
  This function sets all the necessary pins to the default state of the project
*/  

  pinMode(V1pin, OUTPUT);
  pinMode(V2pin, OUTPUT);
  pinMode(P1pin, OUTPUT);
  pinMode(P2pin, OUTPUT);
  digitalWrite(V1pin,LOW);
  digitalWrite(V2pin,LOW);
  digitalWrite(P1pin,LOW);
  digitalWrite(P2pin,LOW);
  
}
////////////////////////////////////
