#!/bin/bash

#SBATCH --job-name=homer
#SBATCH --mem=60gb
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --output=tag_dir_merge_%A-%a.log

# ========== VARIABLES ==========
# put in a file call samples.txt the name of the variables

describer=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samplesmerge.txt)
source ./config.sh

for dir in "${path_homer}" ; do
  if [ ! -d "${dir}" ]; then
    mkdir -p "${dir}"
  fi
done

# ========== MODULES ==========

module load samtools-1.12-gcc-11.2.0-n7fo7p2
module load homer/0.1
module load Java/17.0.2



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

if [ -f "${path_homer}/${describer}_filtered/tagInfo.txt" ]; then
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
    sbatch --array=${array_id}-${array_id} scripts/txtfile_merge.sh
    echo "Number of completed jobs: $(grep 'job successful' tag_dir_merge_${SLURM_ARRAY_JOB_ID}-*.log | wc -l)"
else
    echo "fail"
    echo "Number of completed jobs: $(grep 'job successful' tag_dir_merge_${SLURM_ARRAY_JOB_ID}-*.log | wc -l)"
fi
