#!/bin/sh
#SBATCH --job-name=hicMatrix
#SBATCH --mem=150gb
#SBATCH --time=30:00:00
#SBATCH --cpus-per-task=8
#SBATCH --output=hicMatrix_%A-%a.log


# ========== VARIABLES ==========
# put in a file call samples.txt the name of the variables

describer=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samples.txt)

source ./config.sh

for dir in "${restsite_folder}" ${path_hicMatrix} ${path_coolMatrix} ${path_cooltools} ${path_loops} ; do
  if [ ! -d "${dir}" ]; then
    mkdir -p "${dir}"
  fi
done

# ========== MODULES ==========
module load HiCExplorer/3.7.6-foss-2021b
module load cooler/0.9.1-foss-2021b
module load krbalancing/0.0.5-foss-2021b
module load Miniconda3/4.9
source activate mustache


# ==========  CREATE REST SITES ==========
echo "................................................................ start hicFindRestSite ${describer} ................................................................"

hicFindRestSite --fasta ${refgenome}  --searchPattern ${restrictionSequence} -o ${restsite_folder}/rest_site_positions.bed

echo "................................................................ END hicFindRestSite ................................................................"

# ==========  BUILD HIC MATRIX ========== 
echo " ................................................................ HiCExplorer/3.7.6-foss-2021b start HicBuildMatrix 5kb ${describer} ................................................................"

hicBuildMatrix --samFiles ${path_bam}/${describer}_R1.sam ${path_bam}/${describer}_R2.sam \
        --binSize 5000 --restrictionSequence ${restrictionSequence} --danglingSequence ${danglingSequence} --restrictionCutFile ${restsite_folder}/rest_site_positions.bed \
        --outFileName ${path_hicMatrix}/${describer}_5kb.h5 --QCfolder ${path_hicMatrix}/${describer}_5kb_QC --threads 8 --inputBufferSize 400000

echo "................................................................ end HicBuildMatrix 5kb ${describer} ................................................................"

# ========== GENERATE DIFFERENT RESOLUTION MATRIX ==========
echo "................................................................ START MergeMatrixBins 10kb ${describer} ................................................................"

hicMergeMatrixBins --matrix ${path_hicMatrix}/${describer}_5kb.h5 --numBins 2 --outFileName ${path_hicMatrix}/${describer}_10kb.h5

echo "................................................................ END MergeMatrixBins 10kb ${describer} ................................................................"

echo "................................................................ START MergeMatrixBins 20kb ${describer} ................................................................"

hicMergeMatrixBins --matrix ${path_hicMatrix}/${describer}_5kb.h5 --numBins 4 --outFileName ${path_hicMatrix}/${describer}_20kb.h5

echo "................................................................ END MergeMatrixBins 20kb ${describer} ................................................................"

echo "................................................................ START MergeMatrixBins 50kb ${describer} ................................................................"

hicMergeMatrixBins --matrix ${path_hicMatrix}/${describer}_5kb.h5 --numBins 10 --outFileName ${path_hicMatrix}/${describer}_50kb.h5

echo "................................................................ END MergeMatrixBins 50kb ${describer} ................................................................"

echo "................................................................ START MergeMatrixBins 100kb ${describer} ................................................................"

hicMergeMatrixBins --matrix ${path_hicMatrix}/${describer}_5kb.h5 --numBins 20 --outFileName ${path_hicMatrix}/${describer}_100kb.h5

echo "................................................................ END MergeMatrixBins 100kb ${describer} ................................................................"

# ==========  CORRECT AND CONVERT MATRICES ==========

for number in 5 10 20 50 100
do

echo "................................................................ START hicCorrect KR ${number}kb ${describer} ................................................................"
hicCorrectMatrix correct --correctionMethod KR \
         --matrix ${path_hicMatrix}/${describer}_${number}kb.h5  \
         --chromosomes chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10 chr11 chr12 chr13 chr14 chr15 chr16 chr17 chr18 chr19 chr20 chr21 chr22 chrX chrY \
         --perchr --outFileName ${path_hicMatrix}/${describer}_${number}kb_KR.h5
echo "................................................................ END hicCorrect KR ${number}kb ${describer} ................................................................"

echo "................................................................ START hicConvert to cool ${number}kb ${describer} ................................................................"
hicConvertFormat --matrices ${path_hicMatrix}/${describer}_${number}kb_KR.h5 \
    --outFileName ${path_coolMatrix}/${describer}_${number}kb_KR.cool \
    --inputFormat h5 \
    --outputFormat cool
echo "................................................................ END hicConvert to cool ${number}kb ${describer} ................................................................"

done

# ==========  LOOP CALLING ==========

for number in 5 10 20
do

echo " ................................................................ START mustache ${describer} ................................................................ "
python -m mustache -f ${path_coolMatrix}/${describer}_${number}kb_KR.cool  -r ${number}kb -pt 0.1 -o ${path_loops}/hic_${describer}_loops_01_${number}kb.tsv
python -m mustache -f ${path_coolMatrix}/${describer}_${number}kb_KR.cool  -r ${number}kb -pt 0.05 -o ${path_loops}/hic_${describer}_loops_05_${number}kb.tsv
echo " ................................................................ END mustache ${describer} ................................................................ "

done

module purge
module load cooltools/0.5.2-foss-2021b
module load cooler



# ==========  GENERATE SADDLE PLOTS ==========
echo " ................................................................ START cooltools expected-cis ${describer} ................................................................ "
cooltools expected-cis -p 8 -o ${path_cooltools}/${describer}_100kb_KR_exp.tsv \
   ${path_coolMatrix}/${describer}_100kb_KR.cool
echo " ................................................................ END cooltools expected-cis ${describer} ................................................................ "



echo " ................................................................ START cooltools eigs-cis ${describer} ................................................................ "
cooltools eigs-cis ${path_coolMatrix}/${describer}_100kb_KR.cool \
--phasing-track ${ref_compartments} \
     -o ${path_cooltools}/${describer}_100kb_KR_ev_ac
echo " ................................................................ END cooltools eigs-cis ${describer} ................................................................ "

echo " ................................................................ START awk ${describer} ................................................................ "
awk 'NR>1 {print $1, $2, $3, $5}' ${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv > ${path_cooltools}/${describer}_100kb_EV1_ac.bedgraph
awk 'NR>1 {print $1, $2, $3, $6}' ${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv > ${path_cooltools}/${describer}_100kb_EV2_ac.bedgraph
awk 'NR>1 {print $1, $2, $3, $7}' ${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv > ${path_cooltools}/${describer}_100kb_EV3_ac.bedgraph
echo " ................................................................ END awk ${describer} ................................................................ "

echo " ................................................................ START cooltools saddle ${describer} ................................................................ "

cooltools saddle --qrange 0.02 0.98 --strength \
    --vmin 0.2 --vmax 4 \
    -o ${path_cooltools}/${describer} --fig pdf \
   ${path_coolMatrix}/${describer}_100kb_KR.cool \
    ${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv \
    ${path_cooltools}/${describer}_100kb_KR_exp.tsv

echo " ................................................................ END cooltools saddle ${describer} ................................................................ "
