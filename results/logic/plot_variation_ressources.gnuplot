set encoding utf8
set datafile separator ","

set terminal pdfcairo enhanced color font "Calibri,12" size 16cm,10cm
set output "variation_relative_ressources.pdf"

set title "Variation relative des ressources par rapport à la référence"
set ylabel "Variation relative (%)"
unset xlabel

set style data histograms
set style histogram clustered gap 1
set style fill solid 0.85 border rgb "#333333"
set boxwidth 0.85

set grid ytics back lc rgb "#D9D9D9" lw 1
set border 3
set xtics nomirror rotate by -15
set ytics nomirror
set key outside top center horizontal
set zeroaxis lt 1 lc rgb "#555555" lw 1.2

# Valeurs de référence
lut_ref = 995474.0
ff_ref  = 402101.0

# La référence est omise, puisque sa variation vaut 0 %.
plot "logic-utilization.csv" every ::2 \
        using (100.0*($2-lut_ref)/lut_ref):xticlabels(1) \
        title "LUT" lc rgb "#D96C9D", \
     "" every ::2 \
        using (100.0*($3-ff_ref)/ff_ref) \
        title "FF" lc rgb "#4C78A8"

unset output