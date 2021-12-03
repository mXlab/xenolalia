
////////////////////////
///   OSC HELPERS    ///
////////////////////////

/*
This file contains all the code interaction with the OSC protocol.
      
  Possible OSC adress list : 
     /xeno/pix -> void on_pix(OSCMessage &msg, int addrOffset)
     /xeno/strip -> void on_strip(OSCMessage &msg, int addrOffset)
     /xeno/pumptest -> void on_pumptest(OSCMessage &msg, int addrOffset)
     /xeno/refresh -> void on_refresh(OSCMessage &msg, int addrOffset) 
     /xeno/pumpin -> void on_pumpin(OSCMessage &msg, int addrOffset)
     /xeno/pumpout -> void on_pumpout(OSCMessage &msg, int addrOffset) 
     /xeno/servo -> void on_servo(OSCMessage &msg, int addrOffset)
     /xeno/servotest -> void on_servotest(OSCMessage &msg, int addrOffset) 
     /xeno/shake -> void on_shake(OSCMessage &msg, int addrOffset) 
     /xeno/checkLevel -> void on_checkLevel(OSCMessage &msg, int addrOffset) 
     /xeno/v1 -> void on_v1(OSCMessage &msg, int addrOffset) 
     /xeno/p1 -> void on_p1(OSCMessage &msg, int addrOffset) 
     /xeno/p2 -> void on_p2(OSCMessage &msg, int addrOffset) 
     /xeno/v2 -> void on_v2(OSCMessage &msg, int addrOffset) 


*/


void on_pix(OSCMessage &msg, int addrOffset) 
{
    /*
    This function is a callback for when the osc adress /xeno/pix is received
    It fetches the passed  pixel id and RGB values passed in the osc message and 
    turn the specified pixel on calling the pix(pixnum, rr,gg,bb) function. 
    */
    OSCMessage reply("/debug");
    Serial.println("on_pixel");
    reply.add("on_pixel");
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
    
    int pixnum, rr, gg, bb;
    if(msg.isInt(0))
    {
      pixnum = msg.getInt(0);
    }
    if(msg.isInt(1))
    {
      rr = msg.getInt(1);
    }
    if(msg.isInt(2))
    {
      gg = msg.getInt(2);
    }
    if(msg.isInt(3))
    {
      bb = msg.getInt(3);
    }

    pix(pixnum, rr,gg,bb); 
 
}
///////////////////////////////

void on_strip(OSCMessage &msg, int addrOffset)
{
    /*
    This function is a callback for when the osc adress /xeno/strip is received
    It fetches the passed RGB values passed in the osc message and turn the whole pixel ring
     on calling the stripix(rr,gg,bb) function. 
    */
    OSCMessage reply("/debug");
    Serial.println("on_strip");
    reply.add("on_strip");
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
      
    int rr, gg, bb;
    if(msg.isInt(0))
    {
      rr = msg.getInt(0);
    }
    if(msg.isInt(1))
    {
      gg = msg.getInt(1);
    }
    if(msg.isInt(2))
    {
      bb = msg.getInt(2);
    }

    stripix(rr,gg,bb); 
 
}
///////////////////////////////

void on_pumptest(OSCMessage &msg, int addrOffset) 
{
    /*
    This function is a callback for when the osc adress /xeno/pumptest is received
    It fetches the passed On/Off value in the osc message and start/stop a pump cycle test
    calling the pumpin() and pumpout() functions.
    */
    OSCMessage reply("/debug");

    Serial.println("on_pumptest");
    reply.add("on_pumptest");
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
    
    int var;
    if(msg.isFloat(0))
    {
      var = (int) msg.getFloat(0);
    }
    else if(msg.isInt(0))
    {
      var = msg.getInt(0);
    }

    if(var == 0 ) 
    {
      reply.add("Stopping pumptest");
      Udp.beginPacket(dest, rxport);
      reply.send(Udp);
      Udp.endPacket();
      reply.empty();
    }else{
      reply.add("Starting pumptest");
      Udp.beginPacket(dest, rxport);
      reply.send(Udp);
      Udp.endPacket();
      reply.empty();
    }
    Serial.println("var: ");
    Serial.println(var);
      
    pumpTestFlag = var;

    
    while(pumpTestFlag > 0) //could be written while(pumpTestFlag) ?
    {   
      pumpout();
      delay(2000);
      
      for(int i=1; i<=2; i++)
      {
         ServoShake();
      }
      
      delay(2000);
      //oscUpdate(); //not sure why calling oscupdate in the middle of a callback
      
      Serial.println("pumpTestFlag: "); //this prints exactly the same as var. It is not useful
      Serial.println(pumpTestFlag);
      
      pumpin();
      delay(2000);
    }  
}
///////////////////////////////

void on_refresh(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/refresh is received.
    It fetches the passed On/Off value in the osc message and start a refresh cycle calling
    the reFresh() function.
  */
  OSCMessage reply ("/debug");
  
  Serial.println("on_refresh");  
  reply.add("on_refresh");
  Udp.beginPacket(dest, rxport);
  reply.send(Udp);
  Udp.endPacket();
  reply.empty(); 
  float var;
  if(msg.isFloat(0))
  {
    var = msg.getFloat(0);
  }
  else if(msg.isInt(0))
  {
    var = int(msg.getInt(0));
  }
  if (var>0)
  {
    reFresh();
  }
    
}
///////////////////////////////

void on_pumpin(OSCMessage &msg, int addrOffset)
{
  /*
    This function is a callback for when the osc adress /xeno/pumpin is received.
    If the value 1.0 is received in the message it starts a pumpin cycle calling
    the pumpin() function.
  */
    OSCMessage reply ("/debug");

    Serial.println("on_pumpin");
    reply.add("on_pumpin");
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
    
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
    }
    pumpin();
}
///////////////////////////////


void on_pumpout(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/pumpout is received.
    If the value 1.0 is received in the message it starts a pumpout cycle calling
    the pumpout() function.
  */
    OSCMessage reply ("/debug");
    

    Serial.println("on_pumpout"); 
    reply.add("on_pumpout");
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
    
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
    }
    pumpout();
}
///////////////////////////////

void on_servo(OSCMessage &msg, int addrOffset)
{
  /*
    This function is a callback for when the osc adress /xeno/servo is received.
    It fetches the angle value for the servomotor passed in the osc message and move the 
    motor to the passed angle.
  */

    
    
    OSCMessage reply ("/debug");

    Serial.println("on_servo");
    reply.add("on_servo");
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
    
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
      Serial.println("var: ");
      Serial.println(var);
    }
    
    int servoangle = int(var);
    servo1.write(servoangle);
    sprintf(buff ,"Moving servo to %d degree",servoangle);
    reply.add(buff);
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
    Serial.println("servoangle: ");
    Serial.println(servoangle);
    delay(zpeed);   
}
///////////////////////////////

void on_servotest(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/servotest is received.
    If 1.0 is passed in the OSC message it starts a servo test cycle calling 
    the servo_test() function.
  */ 

    OSCMessage reply ("/debug");

    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
    }

    int rep = int(var);
    sprintf(buff , "Starting servo test of  %d rep" , rep); 
    reply.add(buff);
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
    Serial.print("on_servotest: ");
    Serial.println(rep);
    for(int i=1; i<=rep; i++)
    {
      ServoTest();
    }   
}
///////////////////////////////

void on_shake(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/shake is received.
    When a message is received at this adress it starts a complete shake cycle
    calling the ServoShake() function the number of time specified in the global variables
  */ 
    OSCMessage reply("/debug");
    reply.add("Starting complete shake cycle");
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0); // var is not used in this fucntion
    }
  
    for(int i=1; i<=shaketimes; i++)
    {
      //ServoTest();
      ServoShake();
    }  
}
///////////////////////////////

void on_checkLevel(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/checkLevel is received.
    When a message is received at this adress it check the liquid level in the petridish
    calling the check_liquid() function.
  */
    OSCMessage reply("/debug");
    reply.add("on_checkLevel");
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
    float var;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0); //doesnt use var in this function
    }
    check_liquid();
  
}
///////////////////////////////

void on_v1(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/v1 is received.
    It turns the vavle 1 On/Off when the OSC message receives 0.0/1.0 by setting the 
    valve pin HIGH or LOW and set the pixel ring to the corresponding color for visual 
    feedback
  */ 
    OSCMessage reply ("/debug");   
    float var;
    int valvestatus = 0;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
      valvestatus = int(var);
    }
    else if(msg.isInt(0))
    {
      valvestatus = msg.getInt(0);
    }

    if(valvestatus == 0)
    {
      digitalWrite(V1pin,LOW);
      strip_black();
      reply.add("Turning V1 OFF");
    }
    else
    {
      int CL = check_liquid();  // check liquid level sensor 
      if(CL <= liquidThreshold)
      { 
        digitalWrite(V1pin,HIGH);
        strip_blue();
        reply.add("Turning V1 ON");
      }
      else
      {  
        digitalWrite(V1pin,LOW);
        strip_yellow(); 
        
      }     
    }
    Serial.print("v1: ");
    Serial.println(valvestatus); 
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();   
}
///////////////////////////////

void on_p1(OSCMessage &msg, int addrOffset) 
{
  
  /*
    This function is a callback for when the osc adress /xeno/p1 is received.
    It turns the pump 1 On/Off when the OSC message receives 0.0/1.0 by setting the 
    pump pin HIGH or LOW 
  */
    OSCMessage reply ("/debug");
    float var;
    int pumpstatus = 0;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
      pumpstatus = int(var);
    }
    else if(msg.isInt(0))
    {
      pumpstatus = msg.getInt(0);
    }
    if(pumpstatus == 0)
    {
      digitalWrite(P1pin,LOW);
      reply.add("Turning P1 OFF");

    }
    else
    {
      digitalWrite(P1pin,HIGH);
      reply.add("Turning P1 ON");

    }
    Serial.print("p1: ");
    Serial.println(pumpstatus);
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();
}
///////////////////////////////

void on_p2(OSCMessage &msg, int addrOffset) 
{
  /*
    This function is a callback for when the osc adress /xeno/p2 is received.
    It turns the pump 2 On/Off when the OSC message receives 0.0/1.0 by setting the 
    pump pin HIGH or LOW 
  */
    OSCMessage reply ("/debug");

    float var;
    int pumpstatus = 0;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
      pumpstatus = int(var);
    }
    else if(msg.isInt(0))
    {
      pumpstatus = msg.getInt(0);
    }
    if(pumpstatus == 0)
    {
      digitalWrite(P2pin,LOW);
      reply.add("Turning P2 OFF");
    }
    else
    {
      digitalWrite(P2pin,HIGH);
      reply.add("Turning P2 ON");
    }
    Serial.print("p2: ");
    Serial.println(pumpstatus);
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();      
}
///////////////////////////////

void on_v2(OSCMessage &msg, int addrOffset) 
{  
  /*
    This function is a callback for when the osc adress /xeno/v2 is received.
    It turns the vavle 2 On/Off when the OSC message receives 0.0/1.0 by setting the 
    valve pin HIGH or LOW and set the pixel ring to the corresponding color for visual 
    feedback
  */
    
    OSCMessage reply ("/debug");

    float var;
    int valvestatus = 0;
    if(msg.isFloat(0))
    {
      var = msg.getFloat(0);
      valvestatus = int(var);
    }
    else if(msg.isInt(0))
    {
      valvestatus = msg.getInt(0);
    }
    if(valvestatus == 0)
    {
      digitalWrite(V2pin,LOW);
      strip_black();
      reply.add("Turning V2 OFF");
    }
    else
    {
      digitalWrite(V2pin,HIGH);
      strip_blue();
      reply.add("Turning V2 ON");
    }
    
    Serial.print("v2: ");
    Serial.println(valvestatus);  
    Udp.beginPacket(dest, rxport);
    reply.send(Udp);
    Udp.endPacket();
    reply.empty();  
}
///////////////////////////////////

void oscUpdate() 
{
  /*
  This function update the reception of OSC messages and parses them.
  It points to a callback function if an OSC adress matches one listed below
  */  
  OSCMessage in;
  int size;
  if( (size = Udp.parsePacket()) > 0)
  {
    Serial.println("processing OSC package");
    // parse incoming OSC message
    while(size--) 
    {
      in.fill( Udp.read() );
    }
    
    if(!in.hasError()) 
    {
      in.route("/xeno/pix", on_pix); 
      in.route("/xeno/strip", on_strip); 
      in.route("/xeno/refresh", on_refresh); 
      in.route("/xeno/servo", on_servo);  
      in.route("/xeno/servotest", on_servotest); 
      in.route("/xeno/shake", on_shake); 
      in.route("/xeno/liquid", on_checkLevel); 
      in.route("/xeno/v1", on_v1);  
      in.route("/xeno/v2", on_v2);
      in.route("/xeno/p1", on_p1);  
      in.route("/xeno/p2", on_p2);
      in.route("/xeno/pumpin", on_pumpin);
      in.route("/xeno/pumpout", on_pumpout);
      in.route("/xeno/pumptest", on_pumptest);
    }
     Serial.println("OSC MESSAGE RECEIVED");    
  }
}
