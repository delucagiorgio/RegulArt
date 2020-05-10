# RegulArt - Creative Programming & Computing Final Project

### Group:
* [De Luca Giorgio](mailto:giorgio.deluca@mail.polimi.it)
* [Pizzasegola Virginia](mailto:virginia.pizzasegola@mail.polimi.it)
* [Segato Fabio](mailto:fabio1.segato@mail.polimi.it)

## Video Presentation:

![placeholder](link_to_vid.com)

## Abstract
### Short summary
The goal of this project is creating a visual installation that is reactive to movement, sound volume and its regularity in time. This goal is achieved by joining together creative coding and sound analysis.
### Files included
* regulart.pde: the processing program in charge of the visual side of the application, it translates the audio data received from the environment (via the python scripts) into shapes, colors and movement.
* mic.py: this script retrieves audio from the microphone and computes the autocorrelation in order to communicate to the Processing side whether the current audio stream is regular or not.
* msg.py: this script receives points (in terms of coordinates) from the Processing sides and computes the clusters via DB-Scan 
### Ideal setting
The installation we created would ideally require the acquisition of a clear video image that allows to distinguish movements with respect to the background. This can be achieved with a bright room, possibly without the presence of shadows, with a screen installed on one of the walls (possibly covering the majority of its surface), microphones around the room and visual sensor, such as a kinect.
### Our testing setup
Due to limited resources we tested our application on a laptop using its integrated webcam and a microphone.
### Techniques involved
* Video processing: 
  * Motion Detection
  * Optical Flow
* Sound Processing: Autocorrelation
* OSC
* Particle systems
* Swarm Intelligence
* Clustering
## Dependencies
* PyAudio
* Numpy
* Scipy
* PythonOSC
* Scikit-learn
 
## How to use it
1. Run the python scripts (order is not relevant)
2. Run the processing script, to install Processing go to their [website](https://processing.org/)
