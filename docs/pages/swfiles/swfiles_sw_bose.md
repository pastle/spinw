---
{title: sw_bose( ), keywords: sample, summary: coefficient for boson correlation functions for different temperatures,
  sidebar: sw_sidebar, permalink: swfiles_sw_bose.html, folder: swfiles, mathjax: 'true'}

---
  coefficient for boson correlation functions for different temperatures
 
  C = SW_BOSE(oldT,newT,E)
 
  Input:
 
  oldT      Original temperature in Kelvin.
  newT      New temperature in Kelvin.
  E         Energy in meV, positive is the particle creation side (neutron
            energy loss side in scattering experiment).
 
  Output:
 
  C         Correction coefficients that multiplies the correlation
            function. If any of the input is a vector, C will be also a
            vector with the same dimensions.
 