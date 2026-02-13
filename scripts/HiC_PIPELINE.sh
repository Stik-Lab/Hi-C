#!/bin/sh
#SBATCH --job-name=HICpipeline
#SBATCH --mem=100gb
#SBATCH --time=72:00:00
#SBATCH --cpus-per-task=8
#SBATCH --output=HICpipeline_%A-%a.txt

# ========== VARIABLES ==========
# put in a file call samples.txt the name of the variables

describer=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samples.txt)

source ./config.sh

for dir in "${path_bam}" ; do
  if [ ! -d "${dir}" ]; then
    mkdir -p "${dir}"
  fi
done

# ========== MODULES ==========
module load fastqc-0.11.9-gcc-11.2.0-dd2vd2m
module load Trim_Galore/0.6.6-foss-2021b-Python-3.8.5
module load Perl/5.34.0-GCCcore-11.2.0
module load  R/4.2.1-foss-2021b
module load Bowtie2/2.4.4.1-GCC-11.2.0

# ========== FASTQC ==========
echo "................................................................ 1. START_FASTQC ${describer} ................................................................"

fastqc ${path_fq}/${describer}_*.fastq.gz -o ${path_fq}

echo "................................................................ 1. END_FASTQC ${describer} ................................................................"

# ========== TRIMMING ==========
echo "................................................................ 2. START_TRIM_GALORE ${describer} ................................................................"

trim_galore --output_dir ${path_fq}  --paired ${path_fq}/${describer}_*1.fastq.gz ${path_fq}/${describer}_*2.fastq.gz

echo "................................................................ 2. END_TRIM_GALORE ${describer} ................................................................"

echo "................................................................ 3. START_HICUP_TRUNCATED ${describer} ................................................................"

perl ${HICUP_trunc} --re1 ${restriction_enzyme} ${path_fq}/${describer}_*1_val_1.fq.gz ${path_fq}/${describer}_*2_val_2.fq.gz --zip --outdir ${path_fq}

echo "................................................................ 3. END_HICUP_TRUNCATED ${describer} ................................................................"


# ========== ALIGNMENT ==========
echo "................................................................ 4. START_R1_BOWTIE2 ${describer} ................................................................"
bowtie2 --local -x ${indexgenome} --threads 8 \
    -U ${path_fq}/${describer}_*1_val_*.trunc.* --reorder | samtools view -bS -o ${path_bam}/${describer}_R1.bam
    
echo "................................................................ 4. END_R1_BOWTIE2 ${describer} ................................................................"

echo "................................................................ 5. START_R2_BOWTIE2 ${describer} ................................................................"

bowtie2 --local -x ${indexgenome} --threads 8 \
    -U ${path_fq}/${describer}_*2_val_*.trunc.* --reorder | samtools view -bS -o ${path_bam}/${describer}_R2.bam

echo "................................................................ 5. END_R2_BOWTIE2 ${describer} ................................................................"

if [ "$(grep 'job successful' HICpipeline_*.txt | wc -l)" -eq "${N}" ] && [ "${merge}" ="yes" ]; then
  sbatch --array=1-"${Nmerge}" scripts/merge.sh
fi

echo "${merge}"


# ==========  LAUNCH ANALYSIS SCRIPTS ==========

if [ "$(grep 'job successful' HICpipeline_*.txt | wc -l)" -eq "${N}" ]; then
    sbatch --array=2-2 scripts/tagdir.sh
    sbatch --array=2-2 scripts/hicExplorer_analysis.sh
else
    echo "Number of completed jobs: $(grep 'job successful' HICpipeline_*.txt | wc -l)"
fi
