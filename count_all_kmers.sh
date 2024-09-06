#!/bin/bash
# Usage: ./count_all_kmers.sh <dit_with_fastas> <kmer_length>

# Config
script_dir="$(dirname "$(readlink -f "$0")")"
seq_dir=$1
# specify kmer length
kmer_length=$2

# create dirs
mkdir -p "kmers_$kmer_length/kmers_db" "kmers_$kmer_length/kmers_specific_cnt"

# count all kmers in sequences
echo "COUNT KMERS"
for i in `ls $seq_dir/`; do
  name=`echo $i | awk '{split($0, name, ":"); print name[1]}'`
  echo "  $name"
  jellyfish count -m $kmer_length -s 4M $seq_dir/$i -o $name.jf
  jellyfish dump -ct $name.jf > kmers_$kmer_length/kmers_db/$name.kmers
  rm $name.jf
done

# get specific kmers for each sequence
echo "GET SPECIFIC KMERS"
for name in `ls "kmers_$kmer_length/kmers_db"`; do
  echo "  $name"
  python3 "$script_dir/get_specific_kmers.py" $name "kmers_$kmer_length/kmers_db/" > "kmers_$kmer_length/kmers_specific_cnt/$name.cnt"
done

