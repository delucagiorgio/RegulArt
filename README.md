# RegulArt - Creative Programming & Computing Final Project

### Group:
* [De Luca Giorgio](mailto:giorgio.deluca@mail.polimi.it)
* [Segato Fabio](mailto:fabio1.segato@mail.polimi.it)

## Video Presentation:
[![Video](https://i.imgur.com/qwwWGG5.png)](https://youtu.be/mhMgS2Mgjys)


## Abstract
### Short summary
The goal of this project is creating a visual installation that is reactive to movement, sound volume and its regularity in time. This goal is achieved by joining together creative coding and sound analysis.
### Files included
* `RegulArt/`: the Processing sketch in charge of the visual side of the application, it translates the audio data received from the environment (via the python scripts) into shapes, colors and movement.
* `python/mic.py`: this script retrieves audio from the microphone, detects onsets (spectral flux) and looks for a steady tempo through the autocorrelation of the onset envelope, in order to communicate to the Processing side whether the current audio stream is regular or not, together with the normalized volume.
* `python/msg.py`: this script receives points (in terms of coordinates) from the Processing side and computes the clusters via DBSCAN.
* `start.py`: launches the python scripts and, if `processing-java` is available, the Processing sketch.
### Ideal setting
The installation we created would ideally require the acquisition of a clear video image that allows to distinguish movements with respect to the background. This can be achieved with a bright room, possibly without the presence of shadows, with a screen installed on one of the walls (possibly covering the majority of its surface), microphones around the room and visual sensor, such as a kinect.
### Our testing setup
Due to limited resources we tested our application on a laptop using its integrated webcam and a microphone.
### Techniques involved
* Video processing: 
  * Motion Detection
  * Optical Flow
* Sound Processing: Onset detection (spectral flux), Autocorrelation
* OSC
* Particle systems
* Swarm Intelligence
* Clustering
* MIR features

## Dependencies
### Python (3.7+)
Listed in `requirements.txt`:
* [PyAudio](https://pypi.org/project/PyAudio/)
* [Numpy](https://numpy.org/)
* [Scipy](https://www.scipy.org/)
* [PythonOSC](https://pypi.org/project/python-osc/)
* [Scikit-learn](https://scikit-learn.org/stable/)

### Processing
The sketch builds with [Processing](https://processing.org/) 4.3. Install the following libraries from *Sketch → Import Library → Manage Libraries*:
* Video (The Processing Foundation)
* [OpenCV for Processing](https://github.com/atduskgreg/opencv-processing)
* [oscP5](https://sojamo.de/libraries/oscP5/)
 
## How to use it
1. Install the python dependencies: `pip install -r requirements.txt`
2. Run `python start.py`. If `processing-java` is not on your `PATH`, open `RegulArt/RegulArt.pde` in Processing and press Run.

Alternatively, run `python/msg.py` and `python/mic.py` (order is not relevant) and then the Processing sketch. Both scripts accept `--help` to change IP addresses and ports; the ports used by the sketch are defined at the top of `RegulArt.pde`.

### Interaction
* Mouse click: use the current webcam frame as background reference, to reduce particle generation from static parts of the scene.
* `+` / `-`: increase / decrease the maximum force in the regular state.
* `q` / `a`: increase / decrease cohesion.
* `w` / `s`: increase / decrease separation.
