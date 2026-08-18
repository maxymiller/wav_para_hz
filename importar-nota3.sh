#!/bin/bash

arquivo="$1"

wavoutconfig=work
wavoutconfig_new=out

mkdir -p "$wavoutconfig_new/grub"

nome=$(sed -n 's/^# nome=//p' "$arquivo")
tempo_bloco=$(sed -n 's/^# tempo_bloco=//p' "$arquivo")
top_n=$(sed -n 's/^# top_n=//p' "$arquivo")
awk_hz_max=$(sed -n 's/^# awk_hz_max=//p' "$arquivo")

echo "[$0] nome: $nome"
echo "[$0] tempo_bloco: $tempo_bloco"
echo "[$0] top_n: $top_n"
echo "[$0] awk_hz_max $awk_hz_max"

echo "# tempo_bloco=$tempo_bloco" > "$wavoutconfig_new/grub/${nome}-grub.txt"
echo "# top_n=$top_n" >> "$wavoutconfig_new/grub/${nome}-grub.txt"
echo "# awk_hz_max=$awk_hz_max" >> "$wavoutconfig_new/grub/${nome}-grub.txt"

awk '
/^#/ {next}
{
    i=$1
    j=$2
    loop=0
    while (loop < j) {
        print i
        loop++
    }
}
' "$arquivo" >> "$wavoutconfig_new/grub/${nome}-grub.txt"

echo "[$0] executa:"
echo "./notas_para_grub.sh"
echo "./notas_para_wav.sh"
