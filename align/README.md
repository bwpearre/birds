The entry point is learn_detector.m

At the top of that file are a bunch of configuration parameters.  You can probably leave those untouched, but you should read through them to know what's available.

The required data files are:

* A MATLAB file containing
  * MIC_DATA is an MxN array of doubles, with M samples per song and N songs, all temporally aligned
  * fs is the sampling frequency in Hz

* A MATLAB file containing
  * MIC_DATA is an MxP array of doubles, with M samples per song (same M as above) and P segments of non-song (silence, cage noise, white noise, etc).  Alignment here is irrelevant.
  * fs is the sampling frequency in Hz, and must be the same as above.

I've standardised on requiring the name of the bird, and the directory in which the data files are to be found.
