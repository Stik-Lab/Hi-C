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
-bash-4.2$ cat tagdir.sh
#!/bin/bash

#SBATCH --job-name=homer
#SBATCH --mem=60gb
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --output=tag_dir_%A-%a.log

# ========== VARIABLES ==========
# put in a file call samples.txt the name of the variables

describer=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samples.txt)
source ./config.sh

for dir in "${path_homer}" ; do
  if [ ! -d "${dir}" ]; then
    mkdir -p "${dir}"
  fi
done

# ========== MODULES ==========

module load homer/0.1
module load Java/17.0.2
module load samtools-1.12-gcc-11.2.0-n7fo7p2


echo " ................................................................ START makeTagDirectory 1 ${describer} ................................................................"

if [ ! -f "${path_bam}/${describer}_R1.bam" ] || [ ! -f "${path_bam}/${describer}_R2.bam" ]; then
    echo "ERROR: BAM files missing for ${describer}. Cannot call TagDirectory. Aborting."
    exit 1
fi

if [ -d "${path_homer}/${describer}_unfiltered" ]; then
    echo "SKIP  makeTagDirectory 1 : Output already exists for ${describer}"
else
    makeTagDirectory ${path_homer}/${describer}_unfiltered \
                 ${path_bam}/${describer}_R1.bam,${path_bam}/${describer}_R2.bam \
                 -tbp 1 -illuminaPE
fi

echo " ................................................................ END makeTagDirectory 1 ${describer} ................................................................"



echo " ................................................................ START cp ${describer} ................................................................ "

if [ ! -d "${path_homer}/${describer}_unfiltered" ]; then
    echo "ERROR: Files missing for ${describer}. Cannot cp folder. Aborting."
    exit 1
fi

if [ -d "${path_homer}/${describer}_filtered" ]; then
    echo "SKIP  cp : Output already exists for ${describer}"
else
   cp -r ${path_homer}/${describer}_unfiltered ${path_homer}/${describer}_filtered
fi

echo " ................................................................ END cp ${describer} ................................................................"


echo " ................................................................ START makeTagDirectory 2 ${describer} ................................................................ "

if [ -f "${path_homer}/${describer}_filtered/tagInfo.txt" ] && [ "$(find "${path_homer}/${describer}_filtered" -name "*.bed" | wc -l)" -gt 0 ]; then
    echo "SKIP makeTagDirectory 2 : Already updated and processed for ${describer}"
else

        makeTagDirectory ${path_homer}/${describer}_filtered -update \
                -genome ${genome} -removePEbg \
                -restrictionSite ${restrictionSequence} -both \
                -removeSelfLigation -removeSpikes 10000 5

fi

echo " ................................................................ END makeTagDirectory 2 ${describer} ................................................................ "

echo "................................................................ START hic file ${describer} ................................................................"
if [ -s "${path_homer}/${describer}_filtered/${describer}_filtered.hic" ]; then
    echo "SKIP hic file : .hic file already exists for ${describer}"
else

        tagDir2hicFile.pl ${path_homer}/${describer}_filtered  -juicer auto -genome ${genome} -juicerExe "java -jar juicer_tools.1.9.9_jcuda.0.8.jar" -p 8

fi
echo "................................................................ END hic file ${describer} ................................................................"

array_id=${SLURM_ARRAY_TASK_ID}

if [ -s "${path_homer}/${describer}_filtered/tagInfo.txt" ]; then
    echo "job successful"
    sbatch --array=${array_id}-${array_id} scripts/txtfile.sh
    echo "Number of completed jobs: $(grep 'job successful' tag_dir_${SLURM_ARRAY_JOB_ID}-*.log | wc -l)"
else
    echo "fail"
    echo "Number of completed jobs: $(grep 'job successful' tag_dir_${SLURM_ARRAY_JOB_ID}-*.log | wc -l)"
fi
