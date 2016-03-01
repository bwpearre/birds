times_of_interest =

    0.1500

Resampling data from 48000 Hz to 20000 Hz...
Found 2818 songs.  Using 1000.
Borrowing some non-matching songs from '/Volumes/disk2/winData/lblk121rr'...
Bandpass-filtering the data...
FFT time shift = 0.0015 s
Computing spectrograms...
Using frequencies in [ 1000 8000 ] Hz: 90 frequency samples.
Time window is 30 ms, 19 samples.
2000 training songs.  3636 remain for test.
Computing target jitter compensation...
Creating training set from 2000 songs...
   ...(Allocating 19191 MB for training set X.)

shotgun =

    0.3247    0.7548    1.0000    0.7548    0.3247

Converting neural net data to singles...
Training network with trainlm...
   ...training took 109.133 minutes.
Creating spectral power image...
Computing optimal output thresholds...

FALSE_POSITIVE_COST =

     1

Confusion:      True positive    negative
     output pos      99.4444%     5.64e-3%
            neg       0.556%     99.9944%
Saving as 'detector_lny64_0.15_666Hz_3hid_1000train.mat'...




///// Without jitter compensation /////
FALSE_POSITIVE_COST =

     1

Confusion:      True positive    negative
     output pos      98.7486%     0.0260%
            neg       1.25%     99.9740%
Confusion:      True positive    negative
     output pos      99.7824%     6.82e-3%
            neg       0.218%     99.9932%
Confusion:      True positive    negative
     output pos      98.9119%     7.16e-3%
            neg       1.09%     99.9928%

            
Single syllable @ 0.315
Confusion:      True positive    negative
     output pos      99.6177%     2.00e-3%
            neg       0.382%     99.9980%

            
///// 0.315, jitter correction on /////
     output pos      98.0588%     0.0134%
            neg       1.94%     99.9866%
///// 0.315, jitter correction off /////
Confusion:      True positive    negative
     output pos      99.7238%     3.06e-3%
            neg       0.276%     99.9969%
///// 0.315, jitter correction reversed /////
Confusion:      True positive    negative
     output pos      97.2929%     0.0105%
            neg       2.71%     99.9895%

            
At 315 ms:        True positive    negative
     output pos      99.72588%     1.55e-3%
            neg       0.274%     99.99845%


Another run:
At 150 ms:        True positive    negative
     output pos      97.67184%     2.88e-3%
            neg       2.33%     99.99712%
At 315 ms:        True positive    negative
     output pos      99.61197%     6.65e-4%
            neg       0.388%     99.99933%
At 405 ms:        True positive    negative
     output pos      99.16851%     3.22e-3%
            neg       0.831%     99.99678%
