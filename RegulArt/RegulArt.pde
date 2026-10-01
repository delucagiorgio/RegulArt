import processing.video.*;
import gab.opencv.*;
import java.util.*;
import java.util.concurrent.*;
import oscP5.*;
import netP5.*;

OpenCV opencv;
boolean available = false;
Capture cam;

//Agente per la clusterizzazione
Agent a;
OscP5 oscP5;
OscP5 audioOscP5;
NetAddress location;

//Porte OSC: ricezione dei cluster da msg.py, ricezione dell'audio da mic.py, invio dei punti a msg.py
final int CLUSTER_PORT_IN = 57121;
final int AUDIO_PORT_IN = 58121;
final int CLUSTER_PORT_OUT = 57120;

//Messaggi OSC ricevuti, elaborati all'inizio di ogni draw() sul thread principale
//per evitare modifiche concorrenti allo stato dello sketch
Queue<OscMessage> incomingMessages = new ConcurrentLinkedQueue<OscMessage>();

int cam_w;
int cam_h;

//Soglia per motion detection
float thresholdBack = 40;

boolean reg = false;

//Particelle massime ammesse nel sistema
int MAX_PARTICLES;

//downsampling applicato per velocizzare l'acquisizione dell'immagine
int step = 2;

//Lista dei clusters
List<GravityPoint> pointGravityList;

//Lista dei punti da clusterizzare (ottenuti tramite optical flow and motion detection)
List<PVector> vectors;
// Semaforo per triggerare o meno l'aggiornamento in ogni loop
boolean update = false;

//Lista delle particelle del sistema, al più bands
List<Particle> particles;

//Griglia per la ricerca delle particelle vicine: la cella deve essere almeno
//pari al raggio di vicinato più ampio (coesione, 50 pixel)
SpatialGrid grid;

//Immagine utilizzata in caso si decida di utilizzare il background removal, 
//in caso di default l'immagine è completamente nera (massimizza l'errore)
PImage backgroundImage; 


//Coefficienti per l'applicazione delle forze sulle particelle
//Coesione
float cohesM = 0.5;
//Separazione
float separM = 3;
//Allineamento
float alignM = 0.5;
//Flusso
float fluxM = 0.5;
//Attrazione al cluster
float clustM = 1.5;

//Limitazione delle forze e delle velocità nei due comportamenti (regolare e non regolare)
float maxSpeedIR = 20.0;
float maxForceIR = 3.5;
float maxSpeedR = 20.0;
float maxForceR = 1.5;

//valore corrente del volume espresso in forma normalizzata (0,1)
float curr_volume = 0;

List<Integer> availableSpots;


void setup(){
  fullScreen();
  pixelDensity(1);
  a = new Agent();
  pointGravityList = new ArrayList<GravityPoint>();
  vectors = new ArrayList<PVector>();
  oscP5 = new OscP5(this, CLUSTER_PORT_IN);
  audioOscP5 = new OscP5(this, AUDIO_PORT_IN);
  location = new NetAddress("127.0.0.1", CLUSTER_PORT_OUT);
  cam_w = 80;
  cam_h = 60;
  
  cam = new Capture(this, cam_w,cam_h,30);
  opencv = new OpenCV(this, cam_w, cam_h);
  backgroundImage = createImage(cam_w, cam_h, RGB);

  cam.start();
  colorMode(RGB);
  background(0);
  MAX_PARTICLES = 625;
  availableSpots = new ArrayList<Integer>();
  for(int i = 0; i < MAX_PARTICLES; i++){
     availableSpots.add(i); 
  }
  
  particles = new ArrayList<Particle>(MAX_PARTICLES);
  grid = new SpatialGrid(50);
}

void draw(){
  //elabora i messaggi OSC arrivati dall'ultimo frame
  OscMessage msg;
  while((msg = incomingMessages.poll()) != null){
    handleMessage(msg);
  }
  
  //acquisizione del frame della webcam e calcolo dell'optical flow
  if(cam.available()){
    cam.read();
    opencv.loadImage(cam.copy());
    opencv.calculateOpticalFlow();
    available = true;
  }
  cam.loadPixels();   
  
  fill(0,255);
  noStroke();
  rect(0,0,width, height);

  
  //==================================================//
  //  Rimozione particelle morte  //
  //==================================================//
  //controlla se ci sono particelle morte e nel caso le rimuove
  for(int i = 0; i < particles.size();){
    Particle temp_p = particles.get(i);
    if(temp_p.isDead()){
      availableSpots.add(temp_p.spotId);
      particles.remove(temp_p);
    }else{
      int x_cam = constrain(int(map(temp_p.location.x, width, 0, 0, cam_w)), 0, cam_w - 1);
      int y_cam = constrain(int(map(temp_p.location.y, 0, height, 0, cam_h)), 0, cam_h - 1);
      // aggiorna il colore della particella alla posizione corrente 
      // della stessa rispetto alle informazioni del webcam
      temp_p.c = cam.pixels[x_cam + y_cam * cam_w];
      i++;
    }    
  }
  
  
  //==================================================//
  //  Generazione nuove particelle  //
  //==================================================//
  List<PVector> velPixels = new ArrayList<PVector>();
  List<PVector> movPixels = new ArrayList<PVector>();
  List<Integer> colPixels = new ArrayList<Integer>();
  
  //per ogni pixel dell'immagine corrente
  
  for(int x=0; x < cam_w - step && available; x = min(x+step, cam_w)){
    for(int y=0; y < cam_h - step && available; y = min(y+step, cam_h)){
      
      //Calcoliamo il flusso presente nell'immagine
      PVector d = opencv.getAverageFlowInRegion(x,y,step,step);
      
      // soglia per generazione
      if(d.magSq() > 2){
        //Se oltre la soglia (c'è movimento in quel pixel)
        int loc = x + y * cam_w; // Step 1, what is the 1D pixel location 
        color fgColor = cam.pixels[loc]; // Step 2, what is the foreground color
        color bgColor = backgroundImage.pixels[loc]; // Step 3, what is the background color 
        float r1 = red(fgColor); // Step 4, compare the foreground and background color 
        float g1 = green(fgColor); 
        float b1 = blue(fgColor); 
        float r2 = red(bgColor); 
        float g2 = green(bgColor); 
        float b2 = blue(bgColor); 
        float diff = dist(r1, g1, b1, r2, g2, b2); 
        
        //Confrontiamo il valore di differenza con quello dell'immagine del background:
        // nel caso di background sia fissato dall'utente, aumenta la precisione 
        // della generazione generando meno particelle
        if(!update && diff > thresholdBack){
          float x_new = map(x, 0, cam_w, 0, width);
          float y_new = map(y, 0, cam_h, 0, height);
          PVector p = new PVector(x_new,y_new);
          vectors.add(p);
          movPixels.add(p);
          velPixels.add(d);
          colPixels.add(color(r1,g1,b1));
        } 
      }
    }
  }
  
  //Al fine di garantire una generazione di nuove particelle su tutta la superficie mostrata,
  //mescoliamo l'ordine delle nuove particelle in modo che l'inserimento nel particle system di queste non
  //dipenda dalla posizione che esse occupano all'interno dello schermo.
  //Mescoliamo gli indici, così posizione, velocità e colore restano associati allo stesso pixel
  List<Integer> order = new ArrayList<Integer>(movPixels.size());
  for(int i = 0; i < movPixels.size(); i++){
    order.add(i);
  }
  Collections.shuffle(order);
  
  
  //Scorriamo inoltre tutto l'array tenendo conto della densità delle nuove particelle rispetto al valore massimo ammesso 
  // dal particle system
  int stride = 1 + movPixels.size() / MAX_PARTICLES;
  for(int k = 0; k < order.size(); k += stride){
    int i = order.get(k);
    PVector p = movPixels.get(i);
    if(!availableSpots.isEmpty() && particles.size() < MAX_PARTICLES){
      Integer spot_idx = availableSpots.remove((int)random(availableSpots.size()));
      particles.add(new Particle(p,spot_idx, colPixels.get(i), velPixels.get(i), reg));
    } 
  }
   
  //==================================================//
  //  Clustering process  //
  //==================================================//
  //Se non siamo in fase di aggiornamento 
  //e ci sono punti di movimento da clusterizzare, chiama il server 
  if(!update && vectors.size() > 3){
    update = true;
    a.action(vectors);
  }
  
  //==================================================//
  //  Aggiornamento proprietà particelle  //
  //==================================================//
  grid.rebuild(particles);
  
  //Per ogni particella attiva del sistema
  for(int i = 0; i < particles.size(); i++){
    
    if(pointGravityList != null && pointGravityList.size() > 0){
      //trova il più vicino alla posizione della particella
      List<GravityPoint> tmp = new ArrayList<GravityPoint>(pointGravityList);
      GravityPoint minDist = tmp.get(0);

      for(GravityPoint p : tmp){
        if(p.dist(particles.get(i).location) 
            < minDist.dist(particles.get(i).location)){
          minDist = p;  
        }
      }
      
      GravityPoint gp = new GravityPoint(minDist);
      particles.get(i).setCluster(gp);
    }else{
      particles.get(i).setCluster(null);
    }
    
    //Settiamo la regolarità della particella in modo globale
    particles.get(i).setRegular(reg);

    //disegna il poligono
    particles.get(i).run();
  }
}

//////// user interaction ////////

void keyPressed() {

  switch(key) {

    case '+':
      maxForceR += 0.005;
      println(maxForceR);
      break;
  
    case '-':
      maxForceR -= 0.005;
      println(maxForceR);
      break;
      
    case 'q':
      cohesM += 0.01;
      println(cohesM);
      break;
    
    case 'a':
      cohesM -= 0.01;
      println(cohesM);
      break;
    
    case 's':
      separM -= 0.1;
      println(separM);
      break;
      
    case 'w':
      separM += 0.1;
      println(separM);
      break;

  }
}

//Evento triggerato automaticamente da oscP5 (su un thread separato) quando riceve
//da una porta un messaggio Osc: lo accodiamo per elaborarlo in draw()
void oscEvent(OscMessage msg) {
  incomingMessages.add(msg);
}

void handleMessage(OscMessage msg) {
  
    if(msg.checkAddrPattern("/labels")==true) 
  {
    updateData(msg);}
  else if(msg.checkAddrPattern("/soundRepetition")==true)
  { 
    reg= msg.get(0).intValue() == 1;
    float volume_py = msg.get(1).floatValue();
    curr_volume = constrain(curr_volume + (volume_py - curr_volume) * 0.3, 0, 1);
    //println(msg.get(0).intValue(), curr_volume);
    if(curr_volume < 0.1){
      reg = false;  
    }
  }
}

//Carica i nuovi cluster e resetta le variabili di controllo processo 
void updateData(OscMessage msg){
  
  
  //otteniamo la lista di punti dei cluster
  List<PVector> list = a.reasoning(msg);
  
  //modifichiamo la x per rendere i punti speculari all'utente
  if(list != null && !list.isEmpty()){
    for(PVector p : list){
      p.x = map(p.x, 0, width, width , 0);
    }
    
    //aggioriamo la lista di cluster
    List<GravityPoint> tmp = new ArrayList<GravityPoint>(pointGravityList);
    for(PVector p : list){
      boolean found = false;
      
      
      for(int i = 0; i < tmp.size();){
        // se il cluster esiste da troppo tempo, rimuovilo
        if(tmp.get(i).lifetime < 0){
          tmp.remove(i);
        
        // se il nuovo cluster è abbastanza vicino a quello in analisi, aggiorna i dati del cluster considerato 
        }else if(abs(tmp.get(i).dist(p)) < 20){
          found = true;
          tmp.get(i).x = p.x;  
          tmp.get(i).y = p.y;
          break;
        }else{
          i++;
        }
      }
      
      //Se il cluster non viene trovato, aggiungilo alla lista di quelli già esistenti
      if(!found){
         tmp.add(new GravityPoint(p));
      }
    }
    
    
    // aggiorna il lifetime del cluster
    for(int i = 0; i < tmp.size();i++){
        tmp.get(i).lifetime--;       
    }
    
    //riassegna i cluster alla variabile globale
    pointGravityList = tmp;
  }
  vectors = new ArrayList<PVector>();
  //permetti nuovamente l'invio di punti a Python
  update = false;
}

void mousePressed() { 
  //Se il mouse viene premuto, prendiamo l'immagine corrente della cam come riferimento per il background 
  backgroundImage.copy(cam, 0, 0, cam.width, cam.height, 0, 0, cam.width, cam. height);  
}
