//Griglia spaziale per trovare rapidamente le particelle vicine:
//ogni particella viene confrontata solo con quelle delle celle adiacenti alla sua
//invece che con tutte le particelle del sistema
class SpatialGrid{
  float cellSize;
  int cols;
  int rows;
  List<List<Particle>> cells;

  //cellSize deve essere almeno pari al raggio di vicinato più grande usato dalle forze
  SpatialGrid(float cellSize){
    this.cellSize = cellSize;
    cols = max(1, ceil(width / cellSize));
    rows = max(1, ceil(height / cellSize));
    cells = new ArrayList<List<Particle>>(cols * rows);
    for(int i = 0; i < cols * rows; i++){
      cells.add(new ArrayList<Particle>());
    }
  }

  int col(float x){
    return constrain(floor(x / cellSize), 0, cols - 1);
  }

  int row(float y){
    return constrain(floor(y / cellSize), 0, rows - 1);
  }

  //Ridistribuisce le particelle nelle celle in base alla loro posizione attuale
  void rebuild(List<Particle> list){
    for(List<Particle> cell : cells){
      cell.clear();
    }
    for(Particle p : list){
      cells.get(col(p.location.x) + row(p.location.y) * cols).add(p);
    }
  }

  //Restituisce le particelle contenute nella cella della posizione data e in quelle adiacenti
  List<Particle> neighbors(PVector pos){
    List<Particle> result = new ArrayList<Particle>();
    int c = col(pos.x);
    int r = row(pos.y);
    for(int y = max(0, r - 1); y <= min(rows - 1, r + 1); y++){
      for(int x = max(0, c - 1); x <= min(cols - 1, c + 1); x++){
        result.addAll(cells.get(x + y * cols));
      }
    }
    return result;
  }
}
