#  Folder paths 
path_fq='path_to_fastq'
path_bam='path_to_bamfiles'
restsite_folder='restsite_folder'
path_hicMatrix='path_hicMatrix'
path_homer='path_homer'
path_coolMatrix='path_coolMatrix'
path_loops='path_loops'
path_cooltools='path_cooltools'
path_TADs='path_TADs'
path_cscore='path_cscore'
path_juicerEV='path_juicerEV'

# Files and programs 
HICUP_trunc='hiCUP/HiCUP-0.9.2/hicup_truncater'      # Script used to truncate Hi-C reads at restriction sites. (required)
indexgenome='bowtie2/GRCh38_noalt_as/GRCh38_noalt_as'      # Bowtie2 genome index
refgenome='GRCh38.primary_assembly.genome.fa'      # Reference genome FASTA file
ref_compartments='files/refcool_MRC5_ATAC_100kb.bed'      # BED file with reference A/B compartments.
genome100kb='files/hg38_100kb.bed'     # Genome bins at 100 kb resolution (BED)

# Parameters
N=$(wc -l < samples.txt)      # Number of replicate entries (one line per replicate)
Nmerge=$(wc -l < samplesmerge.txt)      # Number of biological samples (used for merging)
restriction_enzyme='^GATC,MboI'      # Restriction enzyme used in Hi-C (HiCUP format)
restrictionSequence='GATC'      # Restriction site sequence
danglingSequence='GATC'      # Dangling end sequence
genome='hg38'      # Genome assembly
merge='yes/no'       # Enable or disable replicate merging
numRep=2/3      # Number of replicates per biological sample
compartments='cscore/juicer/both'       # Compartment calling program
