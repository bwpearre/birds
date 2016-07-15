The entry point is learn_detector.m



At the top of that file are a bunch of configuration parameters.  You can probably leave those untouched, but you should read through them to know what's available.

The required files are:

* A MATLAB data file (default: 'song.mat') containing
  * song is an MxN array of doubles, with M samples per song and N songs, all temporally aligned
  * nonsong is an MxP array of doubles, with M samples per song (same M as above) and P segments of non-song (silence, cage noise, white noise, etc).  Alignment here is irrelevant.
  * fs is the sampling frequency in Hz

* A MATLAB script file (default: params.m).
  * Leave it empty at first, which will pop up the spectrograms.
    * Then add the line "times_of_interest = [x y]" for trigger times at x and y seconds.
  * It can contain overrides for all of the other parameters whose defaults are in the Parameters section at the top of learn_detector.m
