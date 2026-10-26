# Exécuter depuis ce dossier : gnuplot graphiques_delay.gnuplot
# Les tableaux .dat contiennent 100 * (cycles(DELAY)/cycles(0) - 1).
# Les valeurs manquantes ont été interpolées ou extrapolées linéairement.

set encoding utf8
set terminal pngcairo enhanced size 1800,1000 font 'DejaVu Sans,20'
set datafile separator whitespace
set grid ytics lc rgb '#dddddd' lw 1
set grid xtics lc rgb '#eeeeee' lw 1
set border 3
set tics nomirror
set xrange [-0.2:8.2]
set yrange [0:40]
set xtics (0,1,2,3,4,6,8)
set ytics 0,5,40
set format y '%.0f%%'
set xlabel 'DELAY (cycles ajoutés)'
set ylabel 'Augmentation des cycles par rapport à DELAY = 0'
set key outside right top vertical reverse Left samplen 2 spacing 1.4

set style line 1 lc rgb '#1f77b4' lw 3 pt 7 ps 1.1
set style line 2 lc rgb '#ff7f0e' lw 3 pt 7 ps 1.1
set style line 3 lc rgb '#2ca02c' lw 3 pt 7 ps 1.1
set style line 4 lc rgb '#d62728' lw 3 pt 7 ps 1.1
set style line 5 lc rgb '#9467bd' lw 3 pt 7 ps 1.1

set output 'imatmul_delay_gnuplot.png'
plot 'imatmul_relatif.dat' using 1:2 with linespoints ls 1 title 'S = 8', \
     '' using 1:3 with linespoints ls 2 title 'S = 16', \
     '' using 1:4 with linespoints ls 3 title 'S = 32', \
     '' using 1:5 with linespoints ls 4 title 'S = 64', \
     '' using 1:6 with linespoints ls 5 title 'S = 128'
unset output

set terminal pngcairo enhanced size 2500,950 font 'DejaVu Sans,18'
set style line 1 lc rgb '#0072B2' lw 3 pt 7 ps 1
set style line 2 lc rgb '#D55E00' lw 3 pt 7 ps 1
set style line 3 lc rgb '#009E73' lw 3 pt 7 ps 1

set output 'iconv2d-output_delay_gnuplot.png'
unset key
set multiplot layout 1,3 margins 0.08,0.98,0.24,0.96 spacing 0.05,0
# Légende fixe dans l'espace sous les panneaux : une seule ligne garantie.
set arrow 101 from screen 0.30, screen 0.07 to screen 0.325, screen 0.07 nohead front lw 3 lc rgb '#0072B2'
set arrow 102 from screen 0.46, screen 0.07 to screen 0.485, screen 0.07 nohead front lw 3 lc rgb '#D55E00'
set arrow 103 from screen 0.62, screen 0.07 to screen 0.645, screen 0.07 nohead front lw 3 lc rgb '#009E73'
set object 101 circle at screen 0.3125, screen 0.07 size screen 0.0035 fc rgb '#0072B2' fs solid 1.0 front
set object 102 circle at screen 0.4725, screen 0.07 size screen 0.0035 fc rgb '#D55E00' fs solid 1.0 front
set object 103 circle at screen 0.6325, screen 0.07 size screen 0.0035 fc rgb '#009E73' fs solid 1.0 front
set label 101 'OUTPUT = 64' at screen 0.335, screen 0.07 left
set label 102 'OUTPUT = 128' at screen 0.495, screen 0.07 left
set label 103 'OUTPUT = 256' at screen 0.655, screen 0.07 left
set label 1 'F = 3' at graph 0.5,0.98 center front
plot 'iconv2d_output_relatif.dat' using 1:2 with linespoints ls 1 notitle, \
     '' using 1:3 with linespoints ls 2 notitle, \
     '' using 1:4 with linespoints ls 3 notitle
unset label 1
unset arrow 101
unset arrow 102
unset arrow 103
unset object 101
unset object 102
unset object 103
unset label 101
unset label 102
unset label 103
unset ylabel
set format y ''
set label 2 'F = 5' at graph 0.5,0.98 center front
plot 'iconv2d_output_relatif.dat' using 1:5 with linespoints ls 1 notitle, \
     '' using 1:6 with linespoints ls 2 notitle, \
     '' using 1:7 with linespoints ls 3 notitle
unset label 2
set label 3 'F = 7' at graph 0.5,0.98 center front
plot 'iconv2d_output_relatif.dat' using 1:8 with linespoints ls 1 notitle, \
     '' using 1:9 with linespoints ls 2 notitle
unset label 3
unset multiplot
unset output

set ylabel 'Augmentation des cycles par rapport à DELAY = 0'
set format y '%.0f%%'
set output 'iconv2d-ifmap_delay_gnuplot.png'
set multiplot layout 1,3 margins 0.08,0.98,0.24,0.96 spacing 0.05,0
set arrow 101 from screen 0.30, screen 0.07 to screen 0.325, screen 0.07 nohead front lw 3 lc rgb '#0072B2'
set arrow 102 from screen 0.46, screen 0.07 to screen 0.485, screen 0.07 nohead front lw 3 lc rgb '#D55E00'
set arrow 103 from screen 0.62, screen 0.07 to screen 0.645, screen 0.07 nohead front lw 3 lc rgb '#009E73'
set object 101 circle at screen 0.3125, screen 0.07 size screen 0.0035 fc rgb '#0072B2' fs solid 1.0 front
set object 102 circle at screen 0.4725, screen 0.07 size screen 0.0035 fc rgb '#D55E00' fs solid 1.0 front
set object 103 circle at screen 0.6325, screen 0.07 size screen 0.0035 fc rgb '#009E73' fs solid 1.0 front
set label 101 'IFMAP = 64' at screen 0.335, screen 0.07 left
set label 102 'IFMAP = 128' at screen 0.495, screen 0.07 left
set label 103 'IFMAP = 256' at screen 0.655, screen 0.07 left
set label 1 'F = 3' at graph 0.5,0.98 center front
plot 'iconv2d_ifmap_relatif.dat' using 1:2 with linespoints ls 1 notitle, \
     '' using 1:3 with linespoints ls 2 notitle, \
     '' using 1:4 with linespoints ls 3 notitle
unset label 1
unset arrow 101
unset arrow 102
unset arrow 103
unset object 101
unset object 102
unset object 103
unset label 101
unset label 102
unset label 103
unset ylabel
set format y ''
set label 2 'F = 5' at graph 0.5,0.98 center front
plot 'iconv2d_ifmap_relatif.dat' using 1:5 with linespoints ls 1 notitle, \
     '' using 1:6 with linespoints ls 2 notitle, \
     '' using 1:7 with linespoints ls 3 notitle
unset label 2
set label 3 'F = 7' at graph 0.5,0.98 center front
plot 'iconv2d_ifmap_relatif.dat' using 1:8 with linespoints ls 1 notitle, \
     '' using 1:9 with linespoints ls 2 notitle
unset label 3
unset multiplot
unset output
