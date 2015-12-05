#!/bin/bash
if [ plottingNotebook.ipynb does not exist ];
then
  cp ~/Documents/MATLAB/birds/py/Notebook\ template.ipynb plottingNotebook.ipynb
fi
ipython notebook plottingNotebook.ipynb
