#!/bin/sh
#SBATCH --job-name=merge.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
#SBATCH --mem=150gb
#SBATCH --time=30:00:00
#SBATCH --cpus-per-task=8
#SBATCH --output=merge_%A-%a.log


# ========== VARIABLES ==========
# put in a file call samples.txt the name of the variables
describer=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samplesmerge.txt)

source ./config.sh

# ========== MODULES ==========
module load samtools-1.12-gcc-11.2.0-n7fo7p2

if [ "$numRep" -eq 2 ]; then

# ========== MERGE BAM FILES ==========
for num in 1 2
do

echo "................................................................ start merge sam ${describer}! ................................................................"

    samtools merge ${path_bam}/${describer}_R${num}.bam \
      ${path_bam}/${describer}*1_R${num}.bam \
      ${path_bam}/${describer}*2_R${num}.bam

echo "................................................................ end merge sam ${describer} ................................................................"

done

# ========== SUM MATRICES ==========
echo "............................................................... START sumMatrix ${describer} ..............................................................."

hicSumMatrices --matrices \
    ${path_hicMatrix}/${describer}*1_5kb.h5 \
    ${path_hicMatrix}/${describer}*2_5kb.h5 \
    --outFileName ${path_hicMatrix}/${describer}_5kb.h5

echo "............................................................... END sumMatrix ${describer} ..............................................................."


elif [ "$numRep" -eq 3 ]; then

# ========== MERGE BAM FILES ==========
for num in 1 2
do

echo "................................................................ start merge sam ${describer}! ................................................................"

    samtools merge ${path_bam}/${describer}_R${num}.bam \
      ${path_bam}/${describer}*1_R${num}.bam \
      ${path_bam}/${describer}*2_R${num}.bam \
      ${path_bam}/${describer}*3_R${num}.bam

echo "................................................................ end merge sam ${describer} ................................................................"

done

# ========== SUM MATRICES ==========
echo "............................................................... START sumMatrix ${describer} ..............................................................."

  hicSumMatrices --matrices \
    ${path_hicMatrix}/${describer}*1_5kb.h5 \
    ${path_hicMatrix}/${describer}*2_5kb.h5 \
    ${path_hicMatrix}/${describer}*3_5kb.h5 \
    --outFileName ${path_hicMatrix}/${describer}_5kb.h5
    
echo "............................................................... END sumMatrix ${describer} ..............................................................."

fi

echo "merged successful"

# ==========  LAUNCH ANALYSIS SCRIPTS ==========

if [ "$(grep 'merged successful' merge_*.txt | wc -l)" -eq "${N_merge}" ]; then
    sbatch -array=1-${Nmerge} scripts/tagdir_merge.sh
    sbatch -array=1-${Nmerge} scripts/hicExplorer_analysis_merge.sh
else
    echo "Number of completed jobs: $(grep 'job successful' merge_*.txt | wc -l)"
fi
