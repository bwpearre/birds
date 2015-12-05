#!/bin/bash
if ! [ -s plottingNotebook.ipynb ];
then
  cp ~/Documents/MATLAB/birds/py/notebook_template.ipynb plottingNotebook.ipynb
else
  echo "Notebook exists"
fi
ipython notebook plottingNotebook.ipynb
