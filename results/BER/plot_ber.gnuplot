reset
set encoding utf8

set terminal pdfcairo enhanced color font "Arial,11" size 5.2in,3.6in
set output "comparaison_ber_point_fonctionnement.pdf"

set ylabel "BER résiduelle (× 10^{-13})"
set yrange [0:9]
set ytics 1

set xrange [0.5:2.5]
set xtics ( \
    "SECDED\n(72,64)" 1, \
    "LDPC (144,128)\n3 itérations" 2 \
)

unset key
unset title

set border 3 linewidth 1.2
set tics nomirror out
set grid ytics linewidth 0.6 linecolor rgb "#D8D8D8"

set boxwidth 0.58
set style fill solid 0.85 border rgb "#555555"

$DATA << EOD
1 3.55047
2 8.01049
EOD

plot \
    $DATA using 1:2:(column(1)==1 ? 0xD95F76 : 0x2E8B78) \
        with boxes lc rgb variable notitle, \
    $DATA using 1:2:(sprintf("%.2f",column(2))) \
        with labels offset 0,0.7 \
        font ",11" \
        textcolor rgb "#222222" \
        notitle

unset output