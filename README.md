# kmerer

Get cenhap specific kmers from the set of centromere assemblies

### Specifisity rules: 
- `target` kmer has more than 30 hits in a given assembly
- `background` kmer has less than 10% (of target hit counts) hits in assemblies of other cenhaps

### Dependencies:
- jellifish

### Config:
- insert path to directory with scripts at the top of count_all_kmers.sh

### Run:
- `./count_all_kmers.sh <seq_dir> <kmer_length>`
- <seq_dir> must contain centromere sequences (full chromosomes are too long) with cenhap assignment at the and of name after "_"
