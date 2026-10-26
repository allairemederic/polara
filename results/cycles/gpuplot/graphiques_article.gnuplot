# Run from this directory:
#   gnuplot graphiques_article.gnuplot
# PDF width = 7.16 inches, for a two-column IEEE figure at its native size.
# Font = Times New Roman, 8 pt. The system must have this font installed.
# Data are percentages relative to baseline SECDED for the same workload.

reset
set encoding utf8
set datafile separator whitespace
set datafile missing 'NaN'
set border 3 lw 0.6
set tics nomirror scale 0.5
set style line 1 lc rgb '#0072B2' lw 1.5 pt 7 ps 0.5
set style line 2 lc rgb '#D55E00' lw 1.5 pt 5 ps 0.5
set style line 3 lc rgb '#009E73' lw 1.5 pt 9 ps 0.5
set style line 4 lc rgb '#CC79A7' lw 1.5 pt 13 ps 0.5
set style line 5 lc rgb '#E69F00' lw 1.5 pt 11 ps 0.5

# Figure 2: sensitivity to additional L2 latency.
do for [format_id=1:2] {
    if (format_id == 1) {
        set terminal pdfcairo enhanced color size 3.5in,1.7in font 'Times New Roman,10'
        set output 'delay_sensitivity.pdf'
    } else {
        set terminal pngcairo enhanced size 1400,680 font 'Times New Roman,30'
        set output 'delay_sensitivity.png'
    }
    set size noratio
    set multiplot layout 1,2 margins 0.075,0.985,0.24,0.82 spacing 0.045,0
    set xrange [-0.2:4.2]
    set yrange [0:20]
    set xtics (0,1,2,3,4)
    set ytics 0,2,20
    set format y '%.0f'
    set xlabel 'Added L2 latency (cycles)' font sprintf('Times New Roman,%d', format_id == 1 ? 12 : 36)
    set grid xtics ytics back lc rgb '#606060' lw 1.2 dt 1
    set key top left spacing 1.0 samplen 1.2

   unset object 100

    # Cadre autour des points à DELAY = 1
    set arrow 101 from 0.84,-0.7 to 0.84,7.8 nohead front lc rgb 'black' lw 1.5
    set arrow 102 from 1.16,-0.7 to 1.16,7.8 nohead front lc rgb 'black' lw 1.5
    set arrow 103 from 0.84,7.8 to 1.16,7.8 nohead front lc rgb 'black' lw 1.5
    set arrow 104 from 0.84,-0.7 to 1.16,-0.7 nohead front lc rgb 'black' lw 1.5

    # Flèche horizontale et texte
    set arrow 100 from 2.1,2 to 1.18,2 head filled front lc rgb 'black' lw 1.5
    set label 100 'LDPC latency' at 2.2,2 left front

    set title '(a) imatmul' font sprintf('Times New Roman,%d', format_id == 1 ? 12 : 36)
    set ylabel 'Cycle increase (%)' font sprintf('Times New Roman,%d', format_id == 1 ? 12 : 36)

    plot 'imatmul_delay.dat' using 1:2 with linespoints ls 1 title 'S = 8', \
         '' using 1:3 with linespoints ls 2 title 'S = 16', \
         '' using 1:4 with linespoints ls 3 title 'S = 32', \
         '' using 1:5 with linespoints ls 4 title 'S = 64', \
         '' using 1:6 with linespoints ls 5 title 'S = 128'

    set title '(b) iconv2d' font sprintf('Times New Roman,%d', format_id == 1 ? 12 : 36)
    unset ylabel

    set arrow 101 from 0.84,-0.7 to 0.84,6.1 nohead front lc rgb 'black' lw 1.5
    set arrow 102 from 1.16,-0.7 to 1.16,6.1 nohead front lc rgb 'black' lw 1.5
    set arrow 103 from 0.84,6.1 to 1.16,6.1 nohead front lc rgb 'black' lw 1.5

    plot 'iconv2d-output_delay.dat' using 1:2 with linespoints ls 1 title 'F = 3, O = 64', \
         '' using 1:3 with linespoints ls 2 title 'F = 5, O = 128', \
         '' using 1:4 with linespoints ls 3 title 'F = 5, O = 256', \
         '' using 1:5 with linespoints ls 4 title 'F = 7, O = 128'

    unset multiplot
    do for [i=100:104] {
        unset arrow i
    }
    unset label 100
    unset output
}

# Figure 3: LDPC execution-cycle increase relative to baseline SECDED.
do for [format_id=1:2] {
    if (format_id == 1) {
        set terminal pdfcairo enhanced color size 3.5in,1.65in font 'Times New Roman,8'
        set output 'ldpc_cycle_increase.pdf'
        value_font = 'Times New Roman,7'
    } else {
        set terminal pngcairo enhanced size 1400,720 font 'Times New Roman,25'
        set output 'ldpc_cycle_increase.png'
        value_font = 'Times New Roman,22'
    }

    set size noratio
    set multiplot layout 1,2 margins 0.075,0.985,0.24,0.89 spacing 0.045,0
    unset key
    unset grid
    set grid ytics back lc rgb '#cccccc' lw 1.2 dt 1
    set yrange [0:7]
    set ytics 0,1,7
    set format y '%.0f'
    set xtics autofreq
    set boxwidth 0.62
    set style fill solid 1.0 noborder

    set title '(a) imatmul'
    set ylabel 'Cycle increase (%)'
    set xlabel 'Matrix dimension (S)'
    set xtics rotate by 0
    set xrange [-0.65:5.65]
    plot 'imatmul_ldpc.dat' using 1:2:xticlabels(3) with boxes lc rgb '#0072B2' notitle, \
         '' using 1:($2+0.4):(sprintf('%.1f%%',$2)) with labels font value_font notitle

    set title '(b) iconv2d'
    unset ylabel
    set xlabel 'Convolution Configuration (F, O)'
    set xtics rotate by -45
    set xrange [-0.65:6.65]
    plot 'iconv2d-output_ldpc.dat' using 1:2:xticlabels(3) with boxes lc rgb '#D55E00' notitle, \
         '' using 1:($2+0.4):(sprintf('%.1f%%',$2)) with labels font value_font notitle

    unset multiplot
    unset output
}