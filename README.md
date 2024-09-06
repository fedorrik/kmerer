# kmerer

Get cenhap specific kmers from the set of centromere assemblies

### Specifisity rules: 
- `target` kmer has more than 30 hits in a given assembly
- `background` kmer has less than 10% (of target hit counts) hits in assemblies of other cenhaps

### Dependencies:
- jellifish

### Run:
- `./count_all_kmers.sh <seq_dir> <kmer_length>`
- <seq_dir> must contain centromere sequences (full chromosomes are too long) with cenhap assignment at the and of name after "_"

### to_xlsx script:
- collect all the cnt file from `kmers_specific_cnt` dir to one xlsx file
- Requiers `openpyxl` and `xlsxwriter` pip libraries 
- `python3 to_xlsx.py <path/to/kmers_specific_cnt> <output>.xlsx`
