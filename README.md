This repo contains the progress put forth by Mark Li, Haylen Phung, and Olivia Ruckauf, towards making a 2D finite element analysis (FEA) program in Matlab. 

To run the FEA solver, run the file titled ``phase15_gui.m``. 

This repo contains many sample ``SOLIDWORKS`` files and the resulting ``.dxf`` files. From within the FEA GUI users can load thes e``.dxf`` files or create their own. After this, users can mesh the geometry, apply boundary conditions (constraints and loading), and solve the model. The program can then display a variety of metrics such as stress and strain. 

* Note: user discretion is required in some areas. While the stop button is generally functional, some things, primarily very complex geometry and loading, are outside of Matlab's control and will require Task Manager to quit. *
