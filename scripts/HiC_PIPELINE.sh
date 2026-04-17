#!/bin/sh
#SBATCH --job-name=HICpipeline
#SBATCH --mem=100gb
#SBATCH --time=72:00:00
#SBATCH --cpus-per-task=8
#SBATCH --output=HICpipeline_%A-%a.log

# ========== VARIABLES ==========
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
module load R/4.2.1-foss-2021b
module load Bowtie2/2.4.4.1-GCC-11.2.0
module load samtools-1.12-gcc-11.2.0-n7fo7p2

# Find R1 and R2
R1_RAW=$(ls ${path_fq}/${describer}*{_1,_*1}*.f*q.gz 2>/dev/null | head -n 1)
R2_RAW=$(ls ${path_fq}/${describer}*{_2,_*2}*.f*q.gz 2>/dev/null | head -n 1)

# ========== 1. FASTQC ==========
echo "................................................................ 1. START_FASTQC ${describer} ................................................................"


R1_FASTQC="${path_fq}/$(basename ${R1_RAW%%.*})_fastqc.html"
R2_FASTQC="${path_fq}/$(basename ${R2_RAW%%.*})_fastqc.html"

if [ -s "${R1_FASTQC}" ] && [ -s "${R2_FASTQC}" ]; then
    echo "SKIP FastQC: output already exists for ${describer}"
else
    fastqc "${R1_RAW}" "${R2_RAW}" -o ${path_fq}
fi

echo "................................................................ 1. END_FASTQC ${describer} ................................................................"

# ========== 2. TRIMMING ==========
echo "................................................................ 2. START_TRIM_GALORE ${describer} ................................................................"

R1_TRIM=$(ls ${path_fq}/${describer}*val_1.f*q.gz 2>/dev/null | head -n 1)
R2_TRIM=$(ls ${path_fq}/${describer}*val_2.f*q.gz 2>/dev/null | head -n 1)

if [ -s "${R1_TRIM}" ] && [ -s "${R2_TRIM}" ]; then
    echo "SKIP Trim Galore: trimmed files already exist for ${describer}"
else
    trim_galore --output_dir ${path_fq} --paired "${R1_RAW}" "${R2_RAW}"
    R1_TRIM=$(ls ${path_fq}/${describer}*val_1.f*q.gz | head -n 1)
    R2_TRIM=$(ls ${path_fq}/${describer}*val_2.f*q.gz | head -n 1)
fi

echo "................................................................ 2. END_TRIM_GALORE ${describer} ................................................................"

# ========== 3. HICUP TRUNCATION ==========
echo "................................................................ 3. START_HICUP_TRUNCATED ${describer} ................................................................"

R1_TRUNC=$(ls ${path_fq}/${describer}*val_1*.trunc.fastq.gz 2>/dev/null | head -n 1)
R2_TRUNC=$(ls ${path_fq}/${describer}*val_2*.trunc.fastq.gz 2>/dev/null | head -n 1)

if [ -s "${R1_TRUNC}" ] && [ -s "${R2_TRUNC}" ]; then
    echo "SKIP HiCUP truncation: truncated files already exist for ${describer}"
else
    perl ${HICUP_trunc} --re1 ${restriction_enzyme} \
        ${path_fq}/${describer}_*1_val_1.fq.gz \
        ${path_fq}/${describer}_*2_val_2.fq.gz \
        --zip --outdir ${path_fq}
    R1_TRUNC=$(ls ${path_fq}/${describer}*val_1*.trunc.fastq.gz | head -n 1)
    R2_TRUNC=$(ls ${path_fq}/${describer}*val_2*.trunc.fastq.gz | head -n 1)
fi

echo "................................................................ 3. END_HICUP_TRUNCATED ${describer} ................................................................"

# ========== 4. ALIGNMENT R1 ==========
echo "................................................................ 4. START_R1_BOWTIE2 ${describer} ................................................................"

if [ -s "${path_bam}/${describer}_R1.bam" ]; then
    echo "SKIP Bowtie2 R1: BAM already exists for ${describer}"
else
    bowtie2 --local -x ${indexgenome} --threads 8 \
        -U "${R1_TRUNC}" --reorder | samtools view -bS -o ${path_bam}/${describer}_R1.bam
fi

echo "................................................................ 4. END_R1_BOWTIE2 ${describer} ................................................................"

# ========== 5. ALIGNMENT R2 ==========
echo "................................................................ 5. START_R2_BOWTIE2 ${describer} ................................................................"

if [ -s "${path_bam}/${describer}_R2.bam" ]; then
    echo "SKIP Bowtie2 R2: BAM already exists for ${describer}"
else
    bowtie2 --local -x ${indexgenome} --threads 8 \
        -U "${R2_TRUNC}" --reorder | samtools view -bS -o ${path_bam}/${describer}_R2.bam
fi

echo "................................................................ 5. END_R2_BOWTIE2 ${describer} ................................................................"

# ========== 6. FINAL VALIDATION ==========
if [ -s "${path_bam}/${describer}_R1.bam" ] && [ -s "${path_bam}/${describer}_R2.bam" ]; then
    echo "job successful"
else
    echo "job failed: BAM files are missing or empty for ${describer}"
    exit 1
fi

# ========== 7. LAUNCH DOWNSTREAM ANALYSIS ==========
COMPLETED=$(grep -l "job successful" HICpipeline_${SLURM_ARRAY_JOB_ID}-*.log 2>/dev/null | wc -l)

if [ "$COMPLETED" -eq "$N" ]; then
    echo "All jobs finished successfully. Launching downstream analysis..."
    sbatch --array=1-${N} scripts/tagdir.sh
    sbatch --array=1-${N} scripts/hicExplorer_analysis.sh

    if [ "${merge}" == "yes" ]; then
        sbatch --array=1-${Nmerge} scripts/merge.sh
    fi
fi
