#!/bin/sh
#SBATCH --job-name=merge
#SBATCH --mem=150gb
#SBATCH --time=30:00:00
#SBATCH --cpus-per-task=8
#SBATCH --output=merge_%A-%a.log

# ========== VARIABLES ==========
describer=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samplesmerge.txt)

source ./config.sh

# ========== MODULES ==========
module load samtools-1.12-gcc-11.2.0-n7fo7p2
module load HiCExplorer/3.7.2-foss-2021b

if [ "$numRep" -eq 2 ]; then

    # ========== MERGE BAM FILES ==========
    for num in 1 2
    do
        echo "................................................................ START merge bam ${describer} ................................................................"

        file1=$(ls ${path_bam}/${describer}*1_R${num}.bam 2>/dev/null | head -n 1)
        file2=$(ls ${path_bam}/${describer}*2_R${num}.bam 2>/dev/null | head -n 1)

        if [ ! -s "$file1" ] || [ ! -s "$file2" ]; then
            echo "ERROR: BAM files missing for ${describer} R${num}. Cannot merge. Aborting."
            exit 1
        fi

        if [ -s "${path_bam}/${describer}_R${num}.bam" ]; then
            echo "SKIP merge bam: output already exists for ${describer} R${num}"
        else
            samtools merge ${path_bam}/${describer}_R${num}.bam \
                ${path_bam}/${describer}*1_R${num}.bam \
                ${path_bam}/${describer}*2_R${num}.bam
        fi

        echo "................................................................ END merge bam ${describer} ................................................................"
    done

    # ========== SUM MATRICES ==========
    echo "................................................................ START sumMatrix ${describer} ................................................................"

    hic1=$(ls ${path_hicMatrix}/${describer}*1_5kb.h5 2>/dev/null | head -n 1)
    hic2=$(ls ${path_hicMatrix}/${describer}*2_5kb.h5 2>/dev/null | head -n 1)

    if [ ! -s "$hic1" ] || [ ! -s "$hic2" ]; then
        echo "ERROR: HiC matrix files missing for ${describer}. Cannot sum matrices. Aborting."
        exit 1
    fi

    if [ -s "${path_hicMatrix}/${describer}_5kb.h5" ]; then
        echo "SKIP sumMatrix: output already exists for ${describer}"
    else
        hicSumMatrices --matrices \
            ${path_hicMatrix}/${describer}*1_5kb.h5 \
            ${path_hicMatrix}/${describer}*2_5kb.h5 \
            --outFileName ${path_hicMatrix}/${describer}_5kb.h5
    fi

    echo "................................................................ END sumMatrix ${describer} ................................................................"

elif [ "$numRep" -eq 3 ]; then

    # ========== MERGE BAM FILES ==========
    for num in 1 2
    do
        echo "................................................................ START merge bam ${describer} ................................................................"

        file1=$(ls ${path_bam}/${describer}*1_R${num}.bam 2>/dev/null | head -n 1)
        file2=$(ls ${path_bam}/${describer}*2_R${num}.bam 2>/dev/null | head -n 1)
        file3=$(ls ${path_bam}/${describer}*3_R${num}.bam 2>/dev/null | head -n 1)

        if [ ! -s "$file1" ] || [ ! -s "$file2" ] || [ ! -s "$file3" ]; then
            echo "ERROR: BAM files missing for ${describer} R${num}. Cannot merge. Aborting."
            exit 1
        fi

        if [ -s "${path_bam}/${describer}_R${num}.bam" ]; then
            echo "SKIP merge bam: output already exists for ${describer} R${num}"
        else
            samtools merge ${path_bam}/${describer}_R${num}.bam \
                ${path_bam}/${describer}*1_R${num}.bam \
                ${path_bam}/${describer}*2_R${num}.bam \
                ${path_bam}/${describer}*3_R${num}.bam
        fi

        echo "................................................................ END merge bam ${describer} ................................................................"
    done

    # ========== SUM MATRICES ==========
    echo "................................................................ START sumMatrix ${describer} ................................................................"

    hic1=$(ls ${path_hicMatrix}/${describer}*1_5kb.h5 2>/dev/null | head -n 1)
    hic2=$(ls ${path_hicMatrix}/${describer}*2_5kb.h5 2>/dev/null | head -n 1)
    hic3=$(ls ${path_hicMatrix}/${describer}*3_5kb.h5 2>/dev/null | head -n 1)

    if [ ! -s "$hic1" ] || [ ! -s "$hic2" ] || [ ! -s "$hic3" ]; then
        echo "ERROR: HiC matrix files missing for ${describer}. Cannot sum matrices. Aborting."
        exit 1
    fi

    if [ -s "${path_hicMatrix}/${describer}_5kb.h5" ]; then
        echo "SKIP sumMatrix: output already exists for ${describer}"
    else
        hicSumMatrices --matrices \
            ${path_hicMatrix}/${describer}*1_5kb.h5 \
            ${path_hicMatrix}/${describer}*2_5kb.h5 \
            ${path_hicMatrix}/${describer}*3_5kb.h5 \
            --outFileName ${path_hicMatrix}/${describer}_5kb.h5
    fi

    echo "................................................................ END sumMatrix ${describer} ................................................................"

else
    echo "ERROR: numRep is set to ${numRep} but only 2 or 3 are supported. Aborting."
    exit 1
fi

echo "merged successful"

# ========== LAUNCH ANALYSIS SCRIPTS ==========
COMPLETED=$(grep -l "merged successful" merge_${SLURM_ARRAY_JOB_ID}-*.log 2>/dev/null | wc -l)

if [ "$COMPLETED" -eq "$Nmerge" ]; then
    echo "All ${Nmerge} merge jobs finished. Launching downstream analysis..."
    sbatch --array=1-${Nmerge} scripts/tagdir_merge.sh
    sbatch --array=1-${Nmerge} scripts/hicExplorer_analysis_merge.sh
else
    echo "Completed jobs so far: ${COMPLETED} / ${Nmerge}"
fi
