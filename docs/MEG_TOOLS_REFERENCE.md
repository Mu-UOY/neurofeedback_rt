## Brainstorm
**Link:** https://github.com/brainstorm-tools/brainstorm3

Brainstorm is a collaborative, open-source application for analyzing brain recordings — MEG, EEG, fNIRS, ECoG, depth electrodes, and animal electrophysiology. Its main draw is a rich, intuitive graphical interface that requires no programming knowledge, making it accessible to physicians and researchers alike, while also supporting scripting for batch analysis and reproducible pipelines. It's built with MATLAB (and Java) but ships as a standalone executable, so a MATLAB license isn't required. The project dates back to the late 1990s and has over 35,000 registered user accounts, with hundreds of published studies using it. It's developed by a consortium including McGill, USC, Cleveland Clinic, and CNRS/INSERM (France), and is funded by the NIH.

- Repo: https://github.com/brainstorm-tools/brainstorm3
- Main site: http://neuroimage.usc.edu/brainstorm
- License: GPL-3.0
- Core citation: Tadel F, Baillet S, Mosher JC, Pantazis D, Leahy RM (2011). *Brainstorm: A User-Friendly Application for MEG/EEG Analysis.* Computational Intelligence and Neuroscience, 2011:879716.

---

## FieldTrip
**Link:** https://github.com/fieldtrip/fieldtrip

FieldTrip is a MATLAB toolbox for MEG, EEG, and iEEG analysis, developed at the Donders Institute for Brain, Cognition and Behaviour (Nijmegen, Netherlands) together with collaborating institutes. It offers advanced analysis methods including time-frequency analysis, source reconstruction (dipoles, distributed sources, beamformers), and non-parametric statistical testing. It supports data formats from all major MEG systems (CTF, Neuromag/Elekta/Megin, BTi/4D, Yokogawa/Ricoh, FieldLine) and most popular EEG systems, and provides high-level functions for building custom analysis pipelines, with easy extensibility for new methods.

- Repo: https://github.com/fieldtrip/fieldtrip
- Main site: https://www.fieldtriptoolbox.org
- License: GPL-3.0
- Institution: Donders Institute for Brain, Cognition and Behaviour, Radboud University (with contributions from Karolinska Institute, Max Planck Institute for Psycholinguistics, UCL, and others)

---

## McGill CTF MEG Unit (McConnell Brain Imaging Centre)
**Link:** https://www.mcgill.ca/bic/meg-unit

The MEG Unit at McGill's McConnell Brain Imaging Centre (The Neuro / BIC), inaugurated in 2012, operates a **275-channel CTF MEG 2005 Series** system (CTF MEG International Services Limited Partnership), housed in a magnetically shielded room. Specs:
- 275 axial gradiometer SQUID channels, up to 12 kHz sampling
- 29 reference channels for environmental noise reduction
- 64 simultaneous EEG channels (56 + 8 bipolar)
- Continuous head position tracking; seated or supine positioning
- Auxiliary gear: VPixx ProPixx projector, E-A-RTone earphones, Digitimer stimulators, eye tracking, various response devices
- Stimulus software support: MATLAB/PsychToolbox, Presentation, E-Prime, OpenSesame, PsychoPy; real-time neurofeedback via Brainstorm

The unit supports both research and clinical applications (e.g., presurgical mapping for drug-resistant epilepsy and brain tumors) and is available 24/7 to certified operators. It installed a helium recovery/recycling system in March 2024 (Bluefors/Cryomech liquefier), cutting helium consumption by ~95%.

It is also a hub for open science: it co-develops **Brainstorm** (see above) and maintains the **Open MEG Archive (OMEGA)**, a shared repository of anonymized MEG recordings, and contributed to extending the **BIDS** (Brain Imaging Data Structure) standard to MEG.

**Team:**
- Sylvain Baillet, PhD — Director, MEG Unit
- Marc Lalancette — MEG System Manager
- Raymundo Cassani, PhD — Core Software Developer

- Main page: https://www.mcgill.ca/bic/meg-unit
- OMEGA archive: https://www.mcgill.ca/bic/neuroinformatics/omega
- neuroSPEED lab (Baillet lab): https://www.neurospeed-bailletlab.org/