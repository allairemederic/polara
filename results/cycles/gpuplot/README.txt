Run from the extracted directory:
  gnuplot graphiques_article.gnuplot

Outputs:
  delay_sensitivity.pdf and .png
  ldpc_cycle_increase.pdf and .png

To regenerate .dat files after changing the medians:
  python3 prepare_data.py median_cycles.txt
  gnuplot graphiques_article.gnuplot

The parser excludes values marked interpolated or extrapolated. Missing data remain NaN.
The LDPC figure includes every available baseline/LDPC pair. Missing F=3, dimension=256 pairs are omitted.
The sensitivity figure shows five matrix sizes and four representative workloads per convolution variant.
PDFs use a native 7.16-inch width and 8-point Times New Roman. Install that font locally, or adjust the font name if your system substitutes it. Use the PDF at native width across both columns in IEEEtran. Rescaling changes the physical font size.
Gnuplot is unavailable in the authoring environment, so the script has not been executed here.
