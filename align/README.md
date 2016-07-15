### The entry point is `learn_detector.m`

At the top of that file are a bunch of configuration parameters.  You can probably leave those untouched, but you should read through them to know what's available.  If you do want to touch them, do so by modifying `params.m`, below.

I have set it up so that there's a top-level data directory (`data_base_dir`, currently `'/Volumes/Data/song'`), containing directories for birds, by name (e.g. `lny44`).  This allows you to rapidly switch between training on different birds' data by changing `bird` in the Matlab file.

In our example, `/Volumes/Data/song/lny44` contains the following two files:

* A MATLAB script file (default: `params.m`) contains configuration and training parameters:
  * Leave it empty at first, which will cause `learn_detector` to pop up the spectrograms and then stop (with a harmless error).
    * Then add the line "times_of_interest = [x y z ...]" for trigger times at x, y, and z (etc) seconds.  At least one time of interest is required.
  * It can contain overrides for all of the other parameters whose defaults are in the Configuration section at the top of learn_detector.m


* A MATLAB data file (default: `song.mat`) contains the data:
  * `song`: an MxN array of doubles, with M samples per song and N songs, all temporally aligned
  * `nonsong`: an MxP array of doubles, with M samples per song (same M as above) and P segments of non-song (silence, cage noise, white noise, etc).  Alignment here is irrelevant.
  * `fs`: the sampling frequency in Hz
