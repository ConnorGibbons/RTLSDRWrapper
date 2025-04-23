**Documentation for Util.swift**

Some of the stuff in Utils is a little dense, so I think it makes sense to document it here for when I inevitably forget it, or if someone else wants to know how it works.

---

### Float **NORMALIZATION_FACTOR**
Since we get unsigned 8 bit ints from the rtl-sdr, they can take the values 0-255. It's more
practical to reframe these as values in the range [-1,1]. Multiplying by this factor (1 / 127.5) 
will map 255 -> 2, and 0 -> 0. Subtracting 1 then completes the normalization.

---

### [Float] **IQSAMPLE_FROM_UINT8_LUT**
This is a (pointer to a) lookup table meant to find the corresponding normalized float value for the raw RTL-SDR
output, which are unsigned 8 bit ints (0-255). 
Calculated by casting 0...255 to floats and multiplying by normalization factor.

---

### struct **IQSample** 
Raw rtl-sdr output is in the format: i0q0i1q1... 
This struct is just a more ergonomic way of storing it after converting the ints to floats.
I might remove this, it's nearly identical to DSPComplex (provided in Accelerate)

---

### func **fmDemod**
This function takes in an array of IQSamples and recovers the message signal, assuming the input is 
FM modulated.
To recover the amplitude at a given moment (sample) in the message signal, this function calculates
the *phase difference* between the current sample & the previous. 
To find this, we take the current sample (samples[i]) and multiply it by the conjugate of the
previous. This yields a new sample whose phase is equal to the difference between the two we 
multiplied. The phase (angle from the "real" axis) is extracted with atan2(im,real). atan2 is
preferable because it works as expected in all quadrants, unlike atan(im/real).

---

### func **vDSPfmDemod**
This is intended to give you similar output to fmDemod, but much faster as it uses functions from
Apple's Accelerate library. 
It looks intimidating, but it's actually not bad:

*n* represents the number of samples we'll have after demodulating -- it's 1 less than the input
because you cannot get the difference on the first value. (there is no previous!)
*diffs* is a float array allocated to store our eventual output.

Set up pointers to:
* samples (samplesPtr): UnsafeBufferPointer<IQSample>
* samples[0] (basePointer): UnsafePointer<IQSample>

Next, we make a new pointer "ptr" that points to the same memory address as basePointer, but is
instead treating it as an array of Float instead of IQSample. 
Recall that IQSample is just a struct with two members, i and q, both Float. Therefore in memory, we 
would have:
samples[0].i,samples[0].q,samples[1].i,samples[1].q ... samples[n].i,samples[n].q

We then set up pointers to the first four Floats we will need to access: i0, q0, i1, q1.
Each successive pointer is advanced by "1" (one float's worth of bytes).

Then, **tempReal** and **tempIm** are set up to store the real and imaginary components of each 
product. Mutable buffer pointers are created too (tempRealPtr, tempImPtr). 

Next, we initialize three DSPSplitComplex structs (provided by Accelerate, they just contain 
pointers to the real & imaginary float arrays)

But, there is a crucial difference to note here: The first two structs are **not** the same as the
third memory-wise. 
The pointers for A (and B) might look like they point to distinct arrays, but
they don't! Keep in mind that in reality, they point to different floats at the beginning of the 
original "samples" array. 
This is why a few lines above, a stride of "2" was defined. This basically 
states that to go from i0 to i1 in memory, it actually requires jumping by two floats instead of 1.
Additionally, A and B are actually almost the same! B's pointers are just advanced, so that they
 point to the second real & imaginary values in the samples array. This sets it up so that when we
 can treat A as *prev* and B as *curr* in the multiplication. 
 C is different -- it was initialized with pointers to separate real and imaginary arrays, so the 
 stride for i0 --> i1 is only 1.
 Finally vDSP_zvmul is used to multiply A and B. The last parameter, -1, says to use the conjugate 
 of A while multiplying
 vDSP_zvphas computes the phase values for the complex numbers (our products) now stored in C, and
 writes them to diffs.


