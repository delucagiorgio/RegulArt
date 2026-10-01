import argparse

import numpy as np
from sklearn.cluster import DBSCAN

from pythonosc import dispatcher, osc_server, udp_client


# Dimensione massima di un pacchetto UDP: un messaggio contiene tutti i punti di un frame
MAX_PACKET_SIZE = 65535


class AgentCluster():
    def __init__(self, eps=50, min_samples=3):
        self.dbscan = DBSCAN(eps=eps, min_samples=min_samples)

    #Riceve le coordinate dei punti (x0, y0, x1, y1, ...) e restituisce i centroidi dei cluster
    def reasoning(self, coordinates):
        n_points = len(coordinates) // 2
        samples = np.reshape(np.array(coordinates[:n_points * 2], dtype=float), [-1, 2])
        print("%d new samples" % n_points)
        if n_points == 0:
            return []

        labels = self.dbscan.fit_predict(samples)
        #Escludiamo il rumore di DBSCAN (label -1), che non è un cluster
        clusters = [label for label in np.unique(labels) if label != -1]
        print("%d clusters" % len(clusters))
        return [samples[labels == label].mean(axis=0) for label in clusters]


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

        self.server = osc_server.BlockingOSCUDPServer(
            (ip, port_in), self.dispatcher)
        self.server.max_packet_size = MAX_PACKET_SIZE


    def reasoning(self, name, *data):
        centroids = self.ac.reasoning(data)

        if not centroids:
            # Inviamo il messaggio a Processing contenente un valore di default
            self.client.send_message(self.name_out, -1)
            return

        #Messaggio per Processing: numero di cluster seguito dalle coordinate dei centroidi
        points = [len(centroids)]
        for centroid in centroids:
            points.append(float(centroid[0]))
            points.append(float(centroid[1]))
        self.client.send_message(self.name_out, points)


    def action(self):
        print("... serving")
        self.server.serve_forever()


if __name__ == "__main__":  # this is run if this is the main script
    parser = argparse.ArgumentParser(description="Clustering DBSCAN dei punti di movimento per RegulArt")
    parser.add_argument("--ip", default="127.0.0.1", help="indirizzo su cui ascoltare e di Processing")
    parser.add_argument("--port-in", type=int, default=57120, help="porta su cui ricevere i punti")
    parser.add_argument("--port-out", type=int, default=57121, help="porta OSC di Processing")
    parser.add_argument("--eps", type=float, default=50, help="raggio di vicinato di DBSCAN (pixel)")
    args = parser.parse_args()

    agent = AgentOSC(args.eps, ip=args.ip, port_in=args.port_in, port_out=args.port_out)
    agent.action()
