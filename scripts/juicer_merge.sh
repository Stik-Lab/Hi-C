#!/bin/sh
#SBATCH --job-name=juicerEV1
#SBATCH --mem=80gb
#SBATCH --time=14:00:00
#SBATCH --cpus-per-task=1
#SBATCH --output=juicerEV1merge_%A-%a.log


# ========== VARIABLES ==========
describer=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samplesmerge.txt)

source ./config.sh

for dir in "tmp" "${path_juicerEV}" ; do
  if [ ! -d "${dir}" ]; then
    mkdir -p "${dir}"
  fi
done

module load Java/19.0.2

if [ -s "${path_juicerEV}/juicerEV12_${describer}_tp.bedgraph" ]; then
    echo "SKIP: output already exists for ${describer}"
else

for chr in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y
do

echo "................................................................ START EV1 ${describer} chr ${chr} ................................................................"

java -jar -Xmx20g juicer_tools.1.9.9_jcuda.0.8.jar -p eigenvector KR ${path_homer}/${describer}_filtered/${describer}_filtered.hic chr${chr} BP 100000 tmp/juicerEV12_${describer}_chr${chr}.bedgraph

echo "................................................................ END EV1 ${describer} chr ${chr} ................................................................"

done

######### GENERATE TP

echo "................................................................ START  ${describer} final output ................................................................"

cat tmp/juicerEV12_${describer}_chr{1..22}.bedgraph tmp/juicerEV12_${describer}_chrX.bedgraph tmp/juicerEV12_${describer}_chrY.bedgraph \
> tmp/juicerEV12_${describer}_ALL.bedgraph

paste ${genome100kb} tmp/juicerEV12_${describer}_ALL.bedgraph \
| sed '1d' \
| awk -v OFS='\t' '{if($1!="chrY"){print $1,$2,$3,$4}}' \
> ${path_juicerEV}/juicerEV12_${describer}_tp.bedgraph



echo "................................................................ END ${describer} final output ................................................................"

fi

