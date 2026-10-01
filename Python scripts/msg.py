import numpy as np
from sklearn.cluster import DBSCAN

from pythonosc import dispatcher, osc_server, udp_client



class AgentCluster():
    def __init__(self, eps=50, min_samples=3):
        self.dbscan = DBSCAN(eps=eps, min_samples=min_samples)
        #array per le coordinate dei punti
        self.contours = []

    def reasoning(self, *msg):
        #Se il messaggio è un punto, aggiungilo all'array e attendi il prossimo
        if msg[0][0] != "STOP":
            self.contours.append(msg[0][0])
            self.contours.append(msg[0][1])
            return None

        #La comunicazione dei punti è finita: avvia il clustering
        samples = np.reshape(np.array(self.contours, dtype=float), [-1, 2])
        self.contours = []
        print("%d new samples" % samples.shape[0])
        if samples.shape[0] == 0:
            return samples, np.array([], dtype=int)
        return samples, self.dbscan.fit_predict(samples)


class AgentOSC():
    def __init__(self, eps=50, min_samples=3,
                 ip="127.0.0.1",
                 port_in=57120,
                 port_out=57121,
                 name_in="/cluster",
                 name_out="/labels"):
        self.ac = AgentCluster(eps, min_samples)
        self.name_in = name_in
        self.name_out = name_out

        self.dispatcher = dispatcher.Dispatcher()
        self.dispatcher.map(self.name_in, self.reasoning)
        self.client = udp_client.SimpleUDPClient(ip, port_out)

        #Server bloccante: i messaggi vengono gestiti uno alla volta e nell'ordine di arrivo,
        #così lo STOP non può essere elaborato prima dei punti che lo precedono
        self.server = osc_server.BlockingOSCUDPServer(
            (ip, port_in), self.dispatcher)



    def reasoning(self, name, *data):
        result = self.ac.reasoning(data)
        #Finché lo stream dei punti non è terminato non rispondiamo a Processing
        if result is None:
            return

        samples, labels = result
        #Escludiamo il rumore di DBSCAN (label -1), che non è un cluster
        clusters = [label for label in np.unique(labels) if label != -1]
        print("%d clusters" % len(clusters))

        if not clusters:
            # Inviamo il messaggio a Processing contenente un valore di default
            self.client.send_message(self.name_out, -1)
            return

        #Inizializziamo un'array contenente il numero di clusters
        points = [len(clusters)]
        for label in clusters:
            #Calcoliamo il centroide di quella classe e lo aggiungiamo alla lista da inviare a Processing
            centroid = samples[labels == label].mean(axis=0)
            points.append(float(centroid[0]))
            points.append(float(centroid[1]))
        #Inviamo il messaggio a Processing
        self.client.send_message(self.name_out, points)


    def action(self):
        print("... serving")
        self.server.serve_forever()


if __name__ == "__main__":  # this is run if this is the main script
    agent = AgentOSC(50)
    agent.action()
