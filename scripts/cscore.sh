#!/bin/sh
#SBATCH --job-name=cscore
#SBATCH --mem=50gb
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=4
#SBATCH --output=cscore_%A-%a.log

# ========== VARIABLES ==========
# put in a file call samples.txt the name of the variables

describer=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samples.txt)
array_id=${SLURM_ARRAY_TASK_ID}
source ./config.sh

for dir in "${path_cscore}" ; do
  if [ ! -d "${dir}" ]; then
    mkdir -p "${dir}"
  fi
done

# ========== MODULES ==========
module load cscoretool/1.1

echo " ................................................................ START cscore ${describer} ................................................................ "

if [ -s ${path_cscore}/${describer}*_tp.bedgraph ]; then
    echo "SKIP cscore: output already exists for ${describer}"
else
        CscoreTool1.1 ${genome100kb} \
        homertxt_${array_id}.txt \
        ${path_cscore}/${describer} \
        4 1000000

        for i in "${path_cscore}/${describer}"_cscore.bedgraph
        do
                outfile=$(basename "$i" _cscore.bedgraph)
                sed 1d "$i" | awk -v OFS='\t' '$1 != "chrY" {print $1, $2+1, $3, $4}' > "${path_cscore}/${outfile}_tp.bedgraph"
        done

fi
echo " ................................................................ END cscore ${describer} ................................................................ "
