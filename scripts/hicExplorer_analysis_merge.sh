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
#module load HiCExplorer/3.7.6-foss-2021b
module load HiCExplorer/3.7.2-foss-2021b
module load cooler/0.9.1-foss-2021b
module load krbalancing/0.0.5-foss-2021b
module load Miniconda3/4.9
source activate mustache


# ==========  CREATE REST SITES ==========
echo "................................................................ start hicFindRestSite ${describer} ................................................................"

hicFindRestSite --fasta ${refgenome}  --searchPattern ${restrictionSequence} -o ${restsite_folder}/rest_site_positions.bed

echo "................................................................ END hicFindRestSite ................................................................"

# ========== BUILD HIC MATRIX ==========
echo "................................................................ START hicBuildMatrix 5kb ${describer} ................................................................"

if [ ! -s "${path_bam}/${describer}_R1.bam" ] || [ ! -s "${path_bam}/${describer}_R2.bam" ]; then
    echo "ERROR: BAM files missing for ${describer}. Aborting."
    exit 1
fi

if [ ! -s "${restsite_folder}/rest_site_positions.bed" ]; then
    echo "ERROR: rest site file missing. Aborting."
    exit 1
fi

if [ -s "${path_hicMatrix}/${describer}_5kb.h5" ]; then
    echo "SKIP hicBuildMatrix: 5kb matrix already exists for ${describer}"
else
    hicBuildMatrix --samFiles ${path_bam}/${describer}_R1.bam ${path_bam}/${describer}_R2.bam \
        --binSize 5000 --restrictionSequence ${restrictionSequence} --danglingSequence ${danglingSequence} \
        --restrictionCutFile ${restsite_folder}/rest_site_positions.bed \
        --outFileName ${path_hicMatrix}/${describer}_5kb.h5 \
        --QCfolder ${path_hicMatrix}/${describer}_5kb_QC --threads 8 --inputBufferSize 400000
fi

echo "................................................................ END hicBuildMatrix 5kb ${describer} ................................................................"


# ========== GENERATE DIFFERENT RESOLUTION MATRICES ==========

if [ ! -s "${path_hicMatrix}/${describer}_5kb.h5" ]; then
    echo "ERROR: 5kb matrix missing for ${describer}. Cannot merge bins. Aborting."
    exit 1
fi

for number in 10 20 50 100; do
    bins=$((number / 5))
    echo "................................................................ START MergeMatrixBins ${number}kb ${describer} ................................................................"

    if [ -s "${path_hicMatrix}/${describer}_${number}kb.h5" ]; then
        echo "SKIP MergeMatrixBins: ${number}kb matrix already exists for ${describer}"
    else
        hicMergeMatrixBins --matrix ${path_hicMatrix}/${describer}_5kb.h5 \
            --numBins ${bins} \
            --outFileName ${path_hicMatrix}/${describer}_${number}kb.h5
    fi

    echo "................................................................ END MergeMatrixBins ${number}kb ${describer} ................................................................"
done


# ========== CORRECT AND CONVERT MATRICES ==========

for number in 5 10 20 50 100; do

    echo "................................................................ START hicCorrectMatrix KR ${number}kb ${describer} ................................................................"

    if [ ! -s "${path_hicMatrix}/${describer}_${number}kb.h5" ]; then
        echo "ERROR: ${number}kb matrix missing for ${describer}. Cannot correct. Aborting."
        exit 1
    fi

    if [ -s "${path_hicMatrix}/${describer}_${number}kb_KR.h5" ]; then
        echo "SKIP hicCorrectMatrix: ${number}kb KR matrix already exists for ${describer}"
    else
        hicCorrectMatrix correct --correctionMethod KR \
            --matrix ${path_hicMatrix}/${describer}_${number}kb.h5 \
            --chromosomes chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10 chr11 chr12 chr13 chr14 chr15 chr16 chr17 chr18 chr19 chr20 chr21 chr22 chrX chrY \
            --perchr --outFileName ${path_hicMatrix}/${describer}_${number}kb_KR.h5
    fi

    echo "................................................................ END hicCorrectMatrix KR ${number}kb ${describer} ................................................................"

    echo "................................................................ START hicConvertFormat cool ${number}kb ${describer} ................................................................"

    if [ ! -s "${path_hicMatrix}/${describer}_${number}kb_KR.h5" ]; then
        echo "ERROR: ${number}kb KR matrix missing for ${describer}. Cannot convert. Aborting."
        exit 1
    fi

    if [ -s "${path_coolMatrix}/${describer}_${number}kb_KR.cool" ]; then
        echo "SKIP hicConvertFormat: ${number}kb cool file already exists for ${describer}"
    else
        hicConvertFormat --matrices ${path_hicMatrix}/${describer}_${number}kb_KR.h5 \
            --outFileName ${path_coolMatrix}/${describer}_${number}kb_KR.cool \
            --inputFormat h5 --outputFormat cool
    fi

    echo "................................................................ END hicConvertFormat cool ${number}kb ${describer} ................................................................"

done


# ========== LOOP CALLING ==========

for number in 5 10 20; do

    echo "................................................................ START mustache ${number}kb ${describer} ................................................................"

    if [ ! -s "${path_coolMatrix}/${describer}_${number}kb_KR.cool" ]; then
        echo "ERROR: ${number}kb cool file missing for ${describer}. Cannot call loops. Aborting."
        exit 1
    fi

    if [ -s "${path_loops}/hic_${describer}_loops_01_${number}kb.tsv" ] && [ -s "${path_loops}/hic_${describer}_loops_05_${number}kb.tsv" ]; then
        echo "SKIP mustache: loop files already exist for ${number}kb ${describer}"
    else
        python -m mustache -f ${path_coolMatrix}/${describer}_${number}kb_KR.cool -r ${number}kb -pt 0.1  -o ${path_loops}/hic_${describer}_loops_01_${number}kb.tsv
        python -m mustache -f ${path_coolMatrix}/${describer}_${number}kb_KR.cool -r ${number}kb -pt 0.05 -o ${path_loops}/hic_${describer}_loops_05_${number}kb.tsv
    fi

    echo "................................................................ END mustache ${number}kb ${describer} ................................................................"

done

module purge
module load cooltools/0.5.2-foss-2021b
module load cooler


# ========== GENERATE SADDLE PLOTS ==========

if [ ! -s "${path_coolMatrix}/${describer}_100kb_KR.cool" ]; then
    echo "ERROR: 100kb cool file missing for ${describer}. Cannot run cooltools. Aborting."
    exit 1
fi

echo "................................................................ START cooltools expected-cis ${describer} ................................................................"

if [ -s "${path_cooltools}/${describer}_100kb_KR_exp.tsv" ]; then
    echo "SKIP cooltools expected-cis: output already exists for ${describer}"
else
    cooltools expected-cis -p 8 \
        -o ${path_cooltools}/${describer}_100kb_KR_exp.tsv \
        ${path_coolMatrix}/${describer}_100kb_KR.cool
fi

echo "................................................................ END cooltools expected-cis ${describer} ................................................................"

echo "................................................................ START cooltools eigs-cis ${describer} ................................................................"

if [ -s "${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv" ]; then
    echo "SKIP cooltools eigs-cis: output already exists for ${describer}"
else
    cooltools eigs-cis ${path_coolMatrix}/${describer}_100kb_KR.cool \
        --phasing-track ${ref_compartments} \
        -o ${path_cooltools}/${describer}_100kb_KR_ev_ac
fi

echo "................................................................ END cooltools eigs-cis ${describer} ................................................................"

echo "................................................................ START awk eigenvectors ${describer} ................................................................"

if [ ! -s "${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv" ]; then
    echo "ERROR: eigenvector file missing for ${describer}. Cannot extract bedgraphs. Aborting."
    exit 1
fi

if [ -s "${path_cooltools}/${describer}_100kb_EV1_ac.bedgraph" ] && \
   [ -s "${path_cooltools}/${describer}_100kb_EV2_ac.bedgraph" ] && \
   [ -s "${path_cooltools}/${describer}_100kb_EV3_ac.bedgraph" ]; then
    echo "SKIP awk: bedgraph files already exist for ${describer}"
else
    awk 'NR>1 {print $1, $2, $3, $5}' ${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv > ${path_cooltools}/${describer}_100kb_EV1_ac.bedgraph
    awk 'NR>1 {print $1, $2, $3, $6}' ${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv > ${path_cooltools}/${describer}_100kb_EV2_ac.bedgraph
    awk 'NR>1 {print $1, $2, $3, $7}' ${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv > ${path_cooltools}/${describer}_100kb_EV3_ac.bedgraph
fi

echo "................................................................ END awk eigenvectors ${describer} ................................................................"

echo "................................................................ START cooltools saddle ${describer} ................................................................"

if [ ! -s "${path_cooltools}/${describer}_100kb_KR_exp.tsv" ] || [ ! -s "${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv" ]; then
    echo "ERROR: expected or eigenvector file missing for ${describer}. Cannot run saddle. Aborting."
    exit 1
fi

if [ -s "${path_cooltools}/${describer}.saddledump.npz" ]; then
    echo "SKIP cooltools saddle: output already exists for ${describer}"
else
    cooltools saddle --qrange 0.02 0.98 --strength \
        --vmin 0.2 --vmax 4 \
        -o ${path_cooltools}/${describer} --fig pdf \
        ${path_coolMatrix}/${describer}_100kb_KR.cool \
        ${path_cooltools}/${describer}_100kb_KR_ev_ac.cis.vecs.tsv \
        ${path_cooltools}/${describer}_100kb_KR_exp.tsv
fi

echo "................................................................ END cooltools saddle ${describer} ................................................................"


module load HiCExplorer/3.7.2-foss-2021b
module load krbalancing/0.0.5-foss-2021b

# ========== TAD CALLING ==========
echo "................................................................ START hicFindTADs ${describer} ................................................................"

if [ ! -s "${path_hicMatrix}/${describer}_20kb_KR.h5" ]; then
    echo "ERROR: 20kb KR matrix missing for ${describer}. Cannot call TADs. Aborting."
    exit 1
fi

if [ -s "${path_TADs}/${describer}_20kb_KR_TADs_boundaries.bed" ]; then
    echo "SKIP hicFindTADs: TAD output already exists for ${describer}"
else
    hicFindTADs -m ${path_hicMatrix}/${describer}_20kb_KR.h5 \
        --outPrefix ${path_TADs}/${describer}_20kb_KR_TADs \
        --minDepth 100000 \
        --maxDepth 200000 \
        --step 20000 \
        --thresholdComparisons 0.01 \
        --delta 0.01 \
        --correctForMultipleTesting fdr \
        -p 8
fi

echo "................................................................ END hicFindTADs ${describer} ................................................................"
