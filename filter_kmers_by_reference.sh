#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $0 --fasta REF.fa --bed EXCLUDE.bed --kmer-tables DIR [options]

Required arguments:
  --fasta PATH            Reference FASTA
  --bed PATH              BED file with region(s) to exclude
  --kmer-tables DIR       Directory with kmer tables

Optional arguments:
  --kmer-length INT       K-mer length (default: 18)
  --threads INT           Number of threads for KMC/KMC tools (default: 8)
  --ratio-threshold FLOAT Remove kmer if target_cnt / ref_cnt > threshold (default: 0.1)
  --outdir DIR            Output directory (default: ./kmer_filter_out)
  --help                  Show this help

Example:
  $0 \\
    --fasta /private/groups/migalab/references/CHM13/chm13v2.0.fa \\
    --bed chm13_chr11_active-asat.bed \\
    --kmer-tables kmers-18_r \\
    --kmer-length 18 \\
    --threads 8 \\
    --ratio-threshold 0.1 \\
    --outdir kmers_filter_result
EOF
}

log() {
    echo
    date +"%D %T" | tr "\n" " "
    echo " $*"
}

die() {
    echo "Error: $*" >&2
    exit 1
}

require_file() {
    [[ -f "$1" ]] || die "File not found: $1"
}

require_dir() {
    [[ -d "$1" ]] || die "Directory not found: $1"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found in PATH: $1"
}

is_positive_int() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_positive_number() {
    [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}

# defaults
fasta=""
bed_to_exclude=""
kmer_tables=""
kmer_length=18
threads=8
ratio_threshold=0.1
outdir="kmer_filter_out"

# parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fasta)
            [[ $# -ge 2 ]] || die "Missing value for --fasta"
            fasta="$2"
            shift 2
            ;;
        --bed)
            [[ $# -ge 2 ]] || die "Missing value for --bed"
            bed_to_exclude="$2"
            shift 2
            ;;
        --kmer-tables)
            [[ $# -ge 2 ]] || die "Missing value for --kmer-tables"
            kmer_tables="$2"
            shift 2
            ;;
        --kmer-length)
            [[ $# -ge 2 ]] || die "Missing value for --kmer-length"
            kmer_length="$2"
            shift 2
            ;;
        --threads)
            [[ $# -ge 2 ]] || die "Missing value for --threads"
            threads="$2"
            shift 2
            ;;
        --ratio-threshold)
            [[ $# -ge 2 ]] || die "Missing value for --ratio-threshold"
            ratio_threshold="$2"
            shift 2
            ;;
        --outdir)
            [[ $# -ge 2 ]] || die "Missing value for --outdir"
            outdir="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

# validate
[[ -n "$fasta" ]] || die "--fasta is required"
[[ -n "$bed_to_exclude" ]] || die "--bed is required"
[[ -n "$kmer_tables" ]] || die "--kmer-tables is required"

require_file "$fasta"
require_file "${fasta}.fai"
require_file "$bed_to_exclude"
require_dir "$kmer_tables"

is_positive_int "$kmer_length" || die "--kmer-length must be a positive integer"
is_positive_int "$threads" || die "--threads must be a positive integer"
is_positive_number "$ratio_threshold" || die "--ratio-threshold must be a positive number"

require_cmd bedtools
require_cmd kmc
require_cmd kmc_tools
require_cmd python3
require_cmd awk
require_cmd grep
require_cmd cut
require_cmd find
require_cmd mktemp

mkdir -p "$outdir"

workdir="$(mktemp -d "${outdir%/}/work.XXXXXX")"
cleanup() {
    rm -rf "$workdir"
}
trap cleanup EXIT

genome_txt="$workdir/genome.txt"
complement_bed="$workdir/exclude.complement.bed"
reference_wo_region_fa="$workdir/reference_wo_region.fa"
kmc_tmp="$workdir/kmc_tmp"
reference_db_prefix="$workdir/reference_wo_region"
query_fa="$workdir/query_kmers.fa"
query_db_prefix="$workdir/query_kmers"
common_db_prefix="$workdir/common-kmers"
intersection_dump="$outdir/kmers_in_reference_wo_region.cnt"
filtered_tables_dir="$outdir/filtered_tables"
removed_kmers_tsv="$outdir/removed_kmers.tsv"
stats_txt="$outdir/filter_stats.txt"

mkdir -p "$kmc_tmp"
mkdir -p "$filtered_tables_dir"

log "Removing region of interest from reference"
cut -f1,2 "${fasta}.fai" > "$genome_txt"
bedtools complement -i "$bed_to_exclude" -g "$genome_txt" > "$complement_bed"
bedtools getfasta -fi "$fasta" -bed "$complement_bed" > "$reference_wo_region_fa"

log "Creating reference KMC db"
kmc -t"$threads" -k"$kmer_length" -ci0 -cs10000000 -fa "$reference_wo_region_fa" "$reference_db_prefix" "$kmc_tmp"

log "Preparing query FASTA from kmer tables"
found_any=0
while IFS= read -r -d '' file; do
    found_any=1
    cnt=0
    name="$(basename "$file")"
    name="${name%.kmers.cnt}"

    awk -v name="$name" '
        BEGIN { FS=OFS="\t" }
        NR == 1 && $1 == "kmer" { next }
        {
            cnt++
            print ">" name "-" cnt "\n" $1
        }
    ' "$file"
done < <(find "$kmer_tables" -maxdepth 1 -type f -name '*.kmers.cnt' -print0 | sort -z) > "$query_fa"

[[ "$found_any" -eq 1 ]] || die "No *.kmers.cnt files found in: $kmer_tables"

log "Creating query KMC db"
kmc -fa -k"$kmer_length" -ci0 "$query_fa" "$query_db_prefix" "$kmc_tmp"

log "Intersecting KMC db"
kmc_tools -t"$threads" simple "$reference_db_prefix" "$query_db_prefix" intersect "$common_db_prefix" -ocleft

log "Dumping intersection"
kmc_tools -t"$threads" transform "$common_db_prefix" dump "$intersection_dump"

log "Filtering original kmer tables with Python"
python3 - "$intersection_dump" "$kmer_tables" "$filtered_tables_dir" "$removed_kmers_tsv" "$stats_txt" "$ratio_threshold" <<'PY'
import sys
from pathlib import Path
import pandas as pd

intersection_dump = Path(sys.argv[1])
kmer_tables_dir = Path(sys.argv[2])
filtered_tables_dir = Path(sys.argv[3])
removed_kmers_tsv = Path(sys.argv[4])
stats_txt = Path(sys.argv[5])
ratio_threshold = float(sys.argv[6])

def revcomp(seq: str) -> str:
    return seq.translate(str.maketrans("ACGTacgt", "TGCAtgca"))[::-1]

# read kmers present in reference outside excluded region
ref_df = pd.read_csv(
    intersection_dump,
    sep="\t",
    names=["kmer", "ref_count"],
    header=None
)

if ref_df.empty:
    ref_counts = {}
else:
    ref_df["ref_count"] = pd.to_numeric(ref_df["ref_count"], errors="coerce").fillna(0)
    ref_counts = dict(zip(ref_df["kmer"], ref_df["ref_count"]))

filtered_tables_dir.mkdir(parents=True, exist_ok=True)

removed_rows = []
total_rows_before = 0
total_rows_after = 0

for path in sorted(kmer_tables_dir.glob("*.kmers.cnt")):
    sample_name = path.name[:-10]  # strip ".kmers.cnt"

    df = pd.read_csv(path, sep="\t")
    if "kmer" not in df.columns:
        raise ValueError(f"'kmer' column not found in {path}")

    # choose count column for target counts
    preferred = ["cnt", "count", "n"]
    count_candidates = [c for c in preferred if c in df.columns]
    if count_candidates:
        count_col = count_candidates[0]
    else:
        non_kmer_cols = [c for c in df.columns if c != "kmer"]
        if not non_kmer_cols:
            raise ValueError(f"No count column found in {path}")
        count_col = non_kmer_cols[0]

    total_rows_before += len(df)

    ref_count_list = []
    match_type_list = []

    for kmer in df["kmer"]:
        if kmer in ref_counts:
            ref_count_list.append(ref_counts[kmer])
            match_type_list.append("forward")
        else:
            rc = revcomp(kmer)
            if rc in ref_counts:
                ref_count_list.append(ref_counts[rc])
                match_type_list.append("revcomp")
            else:
                ref_count_list.append(0)
                match_type_list.append("absent")

    df["ref_count"] = ref_count_list
    df["_match_type"] = match_type_list

    target_num = pd.to_numeric(df[count_col], errors="coerce")
    ref_num = pd.to_numeric(df["ref_count"], errors="coerce").fillna(0)

    # correct logic:
    # remove if ref_count / target_count > 0.1
    df["_ratio"] = ref_num / target_num
    mask_remove = df["_ratio"] > ratio_threshold

    if mask_remove.any():
        removed = df.loc[mask_remove].copy()
        removed.insert(0, "sample", sample_name)
        removed_rows.append(removed)

    filtered = df.loc[~mask_remove].copy()

    # keep original columns + ref_count, remove helper columns
    filtered.drop(columns=["_match_type", "_ratio"], inplace=True)

    out_path = filtered_tables_dir / f"{sample_name}_kmers.cnt"
    filtered.to_csv(out_path, sep="\t", index=False)

    total_rows_after += len(filtered)

if removed_rows:
    removed_df = pd.concat(removed_rows, ignore_index=True)
    removed_df.to_csv(removed_kmers_tsv, sep="\t", index=False)
    removed_n = len(removed_df)
else:
    removed_df = pd.DataFrame(columns=["sample"])
    removed_df.to_csv(removed_kmers_tsv, sep="\t", index=False)
    removed_n = 0

pct_removed = (removed_n / total_rows_before * 100) if total_rows_before else 0.0

with open(stats_txt, "w") as out:
    out.write(f"Total rows before filtering:\t{total_rows_before}\n")
    out.write(f"Removed rows:\t{removed_n}\n")
    out.write(f"Percentage removed:\t{pct_removed:.2f}\n")
    out.write(f"Total rows after filtering:\t{total_rows_after}\n")
    out.write(f"Ratio threshold (ref/target):\t{ratio_threshold}\n")

print(f"Total rows before filtering: {total_rows_before}")
print(f"Removed rows: {removed_n}")
print(f"Percentage removed: {pct_removed:.2f}%")
print(f"Total rows after filtering: {total_rows_after}")
print(f"Filtered tables written to: {filtered_tables_dir}")
print(f"Removed rows table written to: {removed_kmers_tsv}")
print(f"Stats written to: {stats_txt}")
PY

log "Done"
echo "Intersection dump: $intersection_dump"
echo "Filtered tables:   $filtered_tables_dir"
echo "Removed kmers:     $removed_kmers_tsv"
echo "Stats:             $stats_txt"