#!/usr/bin/env python3
import argparse
import os


def read_kmer_file(file):
    """Parse a kmer db file into a dictionary {kmer: count}"""
    kmers = {}
    with open(file) as f:
        for line in f:
            line = line.strip().split()
            kmers[line[0]] = line[1]
    return kmers


def main():
    parser = argparse.ArgumentParser(
        description="Find specific kmers from a query file against a kmer database."
    )
    parser.add_argument(
        "-n", "--name",
        required=True,
        help="Query kmer file (e.g. HG02622.pat.cen12_[2].kmers)"
    )
    parser.add_argument(
        "-k", "--kmer-db_dir",
        required=True,
        help="Directory with kmer database files"
    )
    parser.add_argument(
        "-t", "--threshold",
        type=float,
        default=0.1,
        help="Background percent threshold (default: 0.1)"
    )
    parser.add_argument(
        "-ct", "--cnt_threshold",
        type=int,
        default=30,
        help="Minimal target count threshold (default: 30)"
    )
    parser.add_argument(
        "-ht", "--hard_threshold",
        action="store_true",
        help="Apply hard threshold filter: remove kmers with bg_percent > threshold"
    )
    args = parser.parse_args()
    query_kmers_file = os.path.basename(args.name)
    query_cenhap = query_kmers_file.split('_')[-1].split('.')[0]

    db_dir = args.kmer_db_dir
    db_kmers_files = os.listdir(db_dir)
    db_kmers_files.remove(query_kmers_file)

    # read query file
    query_kmers = read_kmer_file(os.path.join(db_dir, query_kmers_file))

    # parse the rest of db
    db_kmers = {}
    for file in db_kmers_files:
        db_kmers[file[:-6]] = read_kmer_file(os.path.join(db_dir, file))

    # find good kmers
    good_kmers = []
    for kmer in query_kmers:
        kmer_cnt = int(query_kmers[kmer])
        if kmer_cnt < args.cnt_threshold:
            continue

        kmer_counts = []
        db_cenhaps = []
        threshold_cnt = kmer_cnt / 10
        for db_genome in db_kmers:
            db_cenhap = db_genome.split('_')[-1].split('.')[0]
            db_cenhaps.append(db_cenhap)
            if kmer not in db_kmers[db_genome]:
                kmer_counts.append('0')
            elif query_cenhap == db_cenhap:
                kmer_counts.append(db_kmers[db_genome][kmer])
            elif int(db_kmers[db_genome][kmer]) < threshold_cnt:
                kmer_counts.append(db_kmers[db_genome][kmer])
            else:
                break
        if len(kmer_counts) == len(db_kmers):
            bg_sum = sum(
                int(kmer_counts[i]) for i in range(len(kmer_counts))
                if db_cenhaps[i] != query_cenhap
            )
            good_kmers.append(
                [kmer, str(kmer_cnt), str(bg_sum),
                 str(round(bg_sum / kmer_cnt, 2))] + kmer_counts
            )

    # sort
    good_kmers = sorted(good_kmers, key=lambda x: int(x[1]), reverse=True)

    # apply hard threshold if requested
    if args.hard_threshold:
        good_kmers = [i for i in good_kmers if float(i[3]) <= args.threshold]

    # print header
    header = ['kmer', query_kmers_file[:-6], 'bg_sum', 'bg_percent', *[i[:-6] for i in db_kmers_files]]
    print('\t'.join(header))

    # print results
    for line in good_kmers:
        print('\t'.join(line))


if __name__ == "__main__":
    main()
