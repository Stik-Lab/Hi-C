#!/bin/bash

#SBATCH --job-name=txt_homer
#SBATCH --mem=60gb
#SBATCH --time=26:00:00
#SBATCH --cpus-per-task=8
#SBATCH --output=homertxt_%a.txt


# ========== VARIABLES ==========
# put in a file call samples.txt the name of the variables

describer=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samples.txt)
source ./config.sh

# ========== MODULES ==========

module load homer/0.1
module load Java/17.0.2

echo " ................................................................ START .txt file ${describer} ................................................................ "

tagDir2hicFile.pl ${path_homer}/${describer}_filtered -genome ${genome} -juicerExe "java -jar juicer_tools.1.9.9_jcuda.0.8.jar" -p 8

echo " ................................................................ END .txt file ${describer} ................................................................ "

echo "job successful"

if [ "$(grep 'END .txt file' homertxt_*.txt | wc -l)" -eq "${N}" ]; then
    sbatch -array=1-$N scripts/cscore.sh
else
    echo "Number of completed jobs: $(grep 'job successful' homertxt_*.txt | wc -l)"
fi
