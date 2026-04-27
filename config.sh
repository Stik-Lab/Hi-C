#  Folder paths 
path_fq='path_to_fastq'
path_bam='path_to_bamfiles'
restsite_folder='restsite_folder'
path_hicMatrix='path_hicMatrix'
path_homer='path_homer'
path_coolMatrix='path_coolMatrix'
path_loops='path_loops'
path_cooltools='path_cooltools'
path_cscore='path_cscore'
path_juicerEV='path_juicerEV'

# Files and programs 
HICUP_trunc='hiCUP/HiCUP-0.9.2/hicup_truncater'   # requirements
indexgenome='/mnt/beegfs/public/references/index/bowtie2/GRCh38_noalt_as/GRCh38_noalt_as'   # requirements
refgenome='/mnt/beegfs/public/references/genome/human/GRCh38.primary_assembly.genome.fa' 
ref_compartments='ref/refcool_MRC5_ATAC_100kb.bed'  # requirements
genome100kb='/mnt/beegfs/eferre/bin/files/hg38/hg38_100kb.bed'

# Parameters
N=$(wc -l < samples.txt)
Nmerge=$(wc -l < samplesmerge.txt)
restriction_enzyme='^GATC,MboI'
restrictionSequence='GATC'
danglingSequence='GATC'
genome='hg38'
merge='yes/no'                 # Enable or disable replicate merging
numRep=2/3
compartments='cscore/juicer/both'
