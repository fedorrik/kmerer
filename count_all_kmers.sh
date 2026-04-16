#!/bin/bash

# Defaults
REVERSE_COMPLEMENT=false
SEQ_DIR=""
KMER_LENGTH=21

# Help
usage() {
    echo "Usage: $0 -d DIR [options]"
    echo "  -d, --dir-with-fastas    Directory with input FASTA/FASTQ files (required)"
    echo "  -k, --kmer-length LENGTH K-mer length (default: 21)"
    echo "  -r, --reverse-complement Count canonical k-mers (treat reverse complements as same)"
    echo "  -ht, --hard-threshold    Apply hard threshold filter (default: soft-threshold)"
    echo "  -ct, --cnt_threshold     Minimal target count threshold (default: 30)"
    echo "  -h, --help               Show this help message"
}

# Parse arguments
REVERSE_COMPLEMENT=false
HARD_THRESHOLD=false
CNT_THRESHOLD=30

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--reverse-complement) REVERSE_COMPLEMENT=true ;;
        -d|--dir-with-fastas) SEQ_DIR="$2"; shift ;;
        -k|--kmer-length) KMER_LENGTH="$2"; shift ;;
        -ct|--cnt_threshold) CNT_THRESHOLD="$2"; shift ;;
        -ht|--hard-threshold) HARD_THRESHOLD=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter: $1"; usage; exit 1 ;;
    esac
    shift
done

echo "K-mer length: $KMER_LENGTH"
echo "Target count threshold: $CNT_THRESHOLD"
echo "Reverse complement: $REVERSE_COMPLEMENT"
echo "Hard threshold: $HARD_THRESHOLD"

# Check required arguments
if [[ -z "$SEQ_DIR" ]]; then
    echo "Error: --dir-with-fastas is required"
    usage
    exit 1
fi

# Set canonical flag
CANONICAL_FLAG=""
if $REVERSE_COMPLEMENT; then
    CANONICAL_FLAG="--canonical"
fi

# Script directory
script_dir="$(dirname "$(readlink -f "$0")")"

# Create output directories
mkdir -p "kmers-${KMER_LENGTH}/kmers_db" "kmers-${KMER_LENGTH}"

# Count k-mers
echo "COUNT KMERS"
for fpath in "$SEQ_DIR"/*; do
    fname=$(basename "$fpath")
    name="${fname%.*}"
    echo "  $name"
    jellyfish count -m "$KMER_LENGTH" -s 4M $CANONICAL_FLAG "$fpath" -o "$name.jf"
    jellyfish dump -ct "$name.jf" > "kmers-${KMER_LENGTH}/kmers_db/${name}.kmers"
    rm "$name.jf"
done

# Extract specific k-mers
echo "GET SPECIFIC KMERS"
for kmers_file in "kmers-${KMER_LENGTH}/kmers_db/"*; do
    name=$(basename "$kmers_file")
    echo "  $name"
    if $HARD_THRESHOLD; then
        python3 "$script_dir/get_specific_kmers.py" --name "$name" --kmer-db_dir "kmers-${KMER_LENGTH}/kmers_db/" --hard_threshold --cnt_threshold "$CNT_THRESHOLD" > "kmers-${KMER_LENGTH}/${name}.cnt"
    else
        python3 "$script_dir/get_specific_kmers.py" --name "$name" --kmer-db_dir "kmers-${KMER_LENGTH}/kmers_db/" --cnt_threshold "$CNT_THRESHOLD" > "kmers-${KMER_LENGTH}/${name}.cnt"
    fi
done

# Cleanup
rm -r "kmers-${KMER_LENGTH}/kmers_db/"
echo "K-mer counting completed"
