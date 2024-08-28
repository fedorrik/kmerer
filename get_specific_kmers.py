# Usage: python3 get_specific_kmers.py <query>.kmers
from sys import argv
from os import listdir


# parse kmer db file
def read_kmer_file(file):
    kmers = {}
    with open(file) as f:
        for line in f:
            line = line.strip().split()
            kmers[line[0]] = line[1]
    return kmers


# read query file
query_kmers_file = argv[1]
query_cenhap = query_kmers_file.split('_')[-1].split('.')[0] # HG02622.pat.cen12_[2].kmers
db_dir = argv[2]
db_kmers_files = listdir(db_dir)
db_kmers_files.remove(query_kmers_file)

query_kmers = read_kmer_file(db_dir + query_kmers_file)

# parse the rest of db
db_kmers = {}
for file in db_kmers_files:
    db_kmers[file[:-6]] = read_kmer_file(db_dir + file)

# find good kmers
good_kmers = []
for kmer in query_kmers:
    kmer_cnt = int(query_kmers[kmer])
    # skip if cnt < 30
    if kmer_cnt < 30:
        continue
    kmer_counts = []
    threshold = kmer_cnt / 10
    for db_genome in db_kmers:
        db_cenhap = db_genome.split('_')[-1].split('.')[0] # HG02622.pat.cen12_[2]
        # no such kmer => write
        if kmer not in db_kmers[db_genome]:
            kmer_counts.append('0')
        # same cenhap => write
        elif query_cenhap == db_cenhap:
            kmer_counts.append(db_kmers[db_genome][kmer])
        # cnt < threshold => write
        elif int(db_kmers[db_genome][kmer]) < threshold:
        #elif int(db_kmers[db_genome][kmer]) >= threshold:
            kmer_counts.append(db_kmers[db_genome][kmer])
        else:
            break
    if len(kmer_counts) == len(db_kmers):
        bg_sum = sum(map(int, kmer_counts))
        good_kmers.append([kmer, str(kmer_cnt), str(bg_sum), str(round(bg_sum / kmer_cnt, 2))] + kmer_counts)

# sort
good_kmers = sorted(good_kmers, key=lambda x: int(x[1]), reverse=True)

# print header
header = ['kmer', query_kmers_file[:-6], 'bg_sum', 'bg_percent', *[i[:-6] for i in db_kmers_files]]
print('\t'.join(header))
# print good kmers
for line in good_kmers:
    print('\t'.join(line))
