//Numero massimo di punti inviati a Python per ogni frame: mantiene il messaggio OSC
//entro la dimensione massima di un pacchetto UDP su tutti i sistemi operativi
final int MAX_CLUSTER_POINTS = 500;


class Agent{
  //Crea i nuovi cluster sotto forma di vettori
  List<PVector> reasoning(OscMessage msg){
    List<PVector> vectorList = null;

    int size = msg.get(0).intValue();
    if(size > 0){
      vectorList = new ArrayList<PVector>();
      for(int i = 1; i < size * 2; i = i + 2){
          vectorList.add(new PVector(msg.get(i).floatValue(), msg.get(i + 1).floatValue()));
      }
    }
    return vectorList;
  }

  //Avvia il processo di clusterizzazione sul server,
  //inviando in un unico pacchetto le informazioni
  //riguardanti le posizioni dei pixel di movimento
  void action(List<PVector> list){
      OscMessage msg = new OscMessage("/cluster");

      //se i punti sono troppi, crea un offset per sottocampionare gli elementi da mandare
      int offset = max(1, ceil(list.size() / (float) MAX_CLUSTER_POINTS));

      for (int i = 0; i < list.size(); i += offset){
        PVector p = list.get(i);
        //Escludo i pixel di contorno
        if(p.x == 0 || p.y == 0 || p.x == width || p.y == height){
            continue;
        }
        msg.add(p.x);
        msg.add(p.y);
      }

      oscP5.send(msg, location);
  }
}
