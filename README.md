# Hi-C Pipeline
This repository contains a complete Hi-C data processing pipeline for generating and analyzing chromatin contact maps. The workflow covers quality control, trimming, restriction site processing, read alignment, matrix generation, loop calling, compartment analysis, and additional downstream analyses.

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#before-starting">Before Starting</a>
      <ul>
        <li><a href="#prepare-the-sample-files">Prepare the sample files</a></li>
        <li><a href="#edit-the-configsh-file">Edit the config.sh file</a></li>
        <li><a href="#hpc-environment">HPC Environment</a></li>
      </ul>
    </li>
    <li><a href="#how-to-run-the-pipeline">How to Run the Pipeline</a></li>
    <li>
      <a href="#step-by-step-description">Step-by-Step Description</a>
      <ul>
        <li>
          <a href="#1-quality-control-and-trimming">1. Quality Control and Trimming</a>
          <ul>
            <li><a href="#fastqc">FastQC</a></li>
            <li><a href="#trim-galore">Trim Galore</a></li>
            <li><a href="#hicup-truncater">HICUP Truncater</a></li>
            <li><a href="#bowtie2-alignment">Bowtie2 Alignment</a></li>
          </ul>
        </li>
        <li><a href="#2-create-homer-tag-directories-and-generate-hi-c-files-tagdirsh">2. Create HOMER Tag Directories and Generate Hi-C Files (tagdir.sh)</a></li>
        <li><a href="#3-compartment-analysis-cscoresh--juicersh">3. Compartment Analysis (cscore.sh / juicer.sh)</a></li>
        <li><a href="#4-hi-c-matrix-generation-and-analysis-hicexplorersh">4. Hi-C Matrix Generation and Analysis (hicexplorer.sh)</a></li>
      </ul>
    </li>
    <li><a href="#outputs">Outputs</a></li>
  </ol>
</details>



   
## Before starting
### 1. Prepare the sample files

You need two input files when working with replicates:

##### samples.txt

Contains one line per replicate. The names must match the FASTQ filenames (without extensions).

Example:
```bash
Sample1_1
Sample1_2
Sample2_1
Sample2_2
Sample3_1
Sample3_2
```

##### samplesmerge.txt

Contains one line per biological sample without replicate suffixes. This file is used for merge steps.

Example:
```bash
sample1
sample2
sample3
```
Make sure both files are consistent with your naming convention and with the variables defined in ```config.sh```.

### 2. Edit the ```config.sh``` file
Update the paths and parameters according to your environment.

#### Folder paths 

```bash
# Example: edit the folder paths
path_fq='path_to_fastq'
path_bam='path_to_bamfiles'
```

#### Reference files and programs

```bash

HICUP_trunc='hiCUP/HiCUP-0.9.2/hicup_truncater'  # Script used to truncate Hi-C reads at restriction sites. (required)
indexgenome='...'                                     # Bowtie2 genome index (required)
refgenome='...'                                       # Reference genome FASTA file
ref_compartments='...'                                # BED file with reference A/B compartments.
genome100kb='...'                                     # Genome bins at 100 kb resolution (BED)

```

#### Parameters

```bash

N=$(wc -l < samples.txt)        # Number of replicate entries (one line per replicate)
Nmerge=$(wc -l < samplesmerge.txt) # Number of biological samples (used for merging)

restriction_enzyme='^GATC,MboI' # Restriction enzyme used in Hi-C (HiCUP format)
restrictionSequence='GATC'     # Restriction site sequence
danglingSequence='GATC'        # Dangling end sequence
genome='hg38'                  # Genome assembly
merge='yes/no'                 # Enable or disable replicate merging
numRep=2                       # Number of replicates per biological sample
compartments='cscore/juicer/both'   # Compartment calling program

```

### 3. HPC environment

This pipeline is designed to run on an HPC cluster using a job scheduler.
Each script loads the required software modules internally.
Before running the pipeline, make sure that all required programs and module names are available in your cluster environment, or adapt the module loading commands to match your local module system.

#### Programs that you need to download

Some required tools are not available as cluster modules and must be installed manually before running the pipeline.

- **Juicer Tools**  
  Download from: https://github.com/aidenlab/juicer/releases  
  A compatible version (e.g. `juicer_tools.1.9.9_jcuda.0.8.jar`) should be selected.  
  The `.jar` file should be placed in the same directory where the pipeline will be executed.

- **HiCUP**  
  Download from: https://github.com/StevenWingett/HiCUP/releases/tag/v0.9.2  
  The folder should be extracted and placed in the same working directory as the pipeline.

Both tools must be accessible (correct paths or executable permissions) before starting the analysis.

- **mustache**  
  Download from: https://github.com/ay-lab/mustache
  Load the necessary modules and prepare the ```mustache``` environment using the following commands:
  
```bash
  module load Miniconda3/24.7.1-0
  source activate
  git clone https://github.com/ay-lab/mustache
  conda env create -f ./mustache/environment.yml
```

## How to run the pipeline

Only the first script needs to be run manually.

```bash
sbatch --array=1-N scripts/HIC_PiPELINE.sh
```
> [!IMPORTANT]
> Replace N with the number of samples in samples.txt

## Step-by-Step Description
### 1. Quality control and trimming

#### FastQC:

- Performs quality control checks on raw R1 and R2 FASTQ files.

**Example command**

```bash
fastqc sample1_*.fastq.gz -o .
```

#### Trim Galore:

- Removes adapter sequences and trims low-quality bases from reads.
- Ensures only high-quality sequences are retained for downstream analysis.
- Improves mapping accuracy and reduces noise in Hi-C contact detection.

**Example command**

```bash
trim_galore --output_dir .  --paired sample1_*1.fastq.gz sample1_*2.fastq.gz
```

#### HICUP Truncater:
- Cuts reads at the nearest restriction enzyme site (defined in config.sh, e.g., GATC for MboI).
- This step increases the specificity of downstream alignment and interaction detection.

**Example command**

```bash
perl HICUP_trunc --re1 GATC sample1_*1_val_1.fq.gz sample1_*2_val_2.fq.gz --zip --outdir .
```

#### Bowtie2 Alignment:
- Aligns R1 and R2 reads separately to the reference genome (indexgenome in config.sh).
- Produces SAM files for each read mate.
- These SAM files serve as the input for downstream interaction pairing and contact map generation.

**Example command**

```bash
bowtie2 --local -x indexgenome --threads 8 \
    -U sample1_R1_val_*.trunc.* --reorder -S sample1_R1.sam
```

### 2. Create HOMER Tag Directories and Generate Hi-C Files (tagdir.sh & txtfile.sh)
- This step converts aligned Hi-C reads (SAM files) into **HOMER tag directories**.
  - Tag directories are HOMER’s internal data format that store mapped read positions in a structured way, making them ready for Hi-C specific processing and analysis.
- From the tag directories, this step produces **Hi-C interaction text files**.
- These .txt files summarize contact frequencies between genomic loci and serve as the input for Cscore analysis.

*This analysis is divided in different steps:*

#### 1. Create unfiltered tag directories from paired SAM files.

```bash
makeTagDirectory sample1_unfiltered \
    sample1_R1.sam,sample1_R2.sam \
    -tbp 1 -illuminaPE
```

- ```tbp 1``` → limits to 1 tag per base to reduce PCR bias
- ```illuminaPE``` → indicates paired-end Illumina sequencing

#### 2. Copy unfiltered directories to create a working filtered directory:

```bash
cp -r sample1_unfiltered sample1_filtered
```

#### 3. Filter and clean tag directories to remove biases and technical artifacts:

```bash
makeTagDirectory sample1_filtered -update \
    -genome hg38 -removePEbg \
    -restrictionSite GATC -both \
    -removeSelfLigation -removeSpikes 10000 5
```
- ```removePEbg``` → removes random background interactions
- ```restrictionSite``` → specify enzyme cut site used in Hi-C (e.g. HindIII, MboI)
- ```removeSelfLigation``` → filters self-ligated fragments
- ```removeSpikes 10000 5``` → removes read pileups

#### 4. Generate .hic files (Juicer-compatible) for downstream visualization and interaction analysis:

```bash
tagDir2hicFile.pl sample1_filtered \
    -juicer auto \
    -genome hg38 \
    -juicerExe "java -jar juicer_tools.1.9.9_jcuda.0.8.jar" \
    -p 4
```
**Output Files**
- A set of HOMER tag directories (*_unfiltered and *_filtered).
- A ```.hic``` file for each sample.
-  Hi-C interaction text files.

### 3. Compartment Analysis (cscore.sh/juicer.sh)
 
- This step calculates compartment scores from Hi-C data. Computing A/B compartments is a technically challenging step where results can vary depending on the method used. For this reason, the pipeline offers two approaches — **CscoreTool** and **Juicer eigenvector** — which can be run independently or together by setting the ``compartments`` parameter in ``config.sh`` (``cscore``, ``juicer``, or ``both``).
- C-scores quantify large-scale chromatin organization by identifying A/B compartments, which are associated with transcriptional activity (A) or inactivity (B). The script takes as input Hi-C interaction text files (produced from HOMER tag directories) and outputs compartment score values along the genome.


#### Option 1- CscoreTool

Takes as input Hi-C interaction text files produced from HOMER tag directories and outputs compartment score values along the genome.

```bash
CscoreTool1.1 ${genome100kb} \
    homertxt_${array_id}.txt \
    sample1 \
    4 100000
```

- ```${genome100kb}``` → Genome binning file at 100 kb resolution
- ```homertxt_${array_id}.txt``` → Hi-C interaction text file generated from the previous step
- ```sample1``` → Output prefix and directory for results
- ```4``` → Number of processing threads
- ```100000``` → Window size (100kb) for calculating correlation patterns

#### Option 2 - Juicer Egienvector

Takes as input the ``.hic`` file generated from the HOMER tag directory step and computes the first eigenvector (PC1) at 100 kb resolution using KR normalization. The sign of the eigenvector corresponds to A/B compartment identity.

```bash
java -jar -Xmx20g juicer_tools.1.9.9_jcuda.0.8.jar eigenvector \
    KR \
    ${path_homer}/${describer}_filtered/${describer}_filtered.hic \
    chr${chr} \
    BP 100000 \
    tmp/juicerEV12_${describer}_chr${chr}.bedgraph
```
- ```eigenvector``` → Computes the first principal component (PC1) of the KR-normalized Pearson correlation matrix
- ```KR``` → KR (Knight-Ruiz) normalization, recommended for compartment analysis
- ```${describer}_filtered.hic``` → Input .hic file from the HOMER tag directory step
- ```chr${chr}``` → Chromosome to analyze (run in a loop over all chromosomes)
- ```BP 100000``` → Base-pair resolution, set to 100 kb
- ```tmp/juicerEV12_${describer}_chr${chr}.bedgraph``` → Output eigenvector file per chromosome

The eigenvector is computed per chromosome and stored as temporary files in ``tmp/``. These are then concatenated and merged with genome coordinates into a single genome-wide bedgraph file as the final output: ``juicerEV12_${describer}_tp.bedgraph``
This file contains four columns: ``chr``, ``start``, ``end``, ``eigenvector value``, at **100** kb resolution across all chromosomes and chrX. ChrY is excluded from the final output. The per-chromosome temporary files in tmp/ are intermediate and not needed after the pipeline completes.

> [!Note]
> The Juicer eigenvector and CscoreTool outputs may have opposite signs for A/B compartments depending on the chromosome. Always validate the sign assignment by correlating with an external reference before interpreting the results.

### 5. Hi-C matrix generation and analysis (hicExplorer_analysis.sh)

This step handles the full downstream processing of Hi-C data: from building raw contact matrices to loop calling, compartment analysis, and TAD detection. It is designed to be robust, with skip checks at every step to allow safe re-runs if a job is interrupted.

#### Restriction Site Detection
Identifies restriction enzyme cut sites in the reference genome. The output BED file is shared across all samples and only needs to be generated once.

```bash
hicFindRestSite --fasta ${refgenome} \
    --searchPattern ${restrictionSequence} \
    -o ${restsite_folder}/rest_site_positions.bed
```

#### Contact Matrix Construction
Builds raw contact matrices at 5 kb resolution from the paired BAM files.

```bash
hicBuildMatrix --samFiles R1.bam R2.bam \
    --binSize 5000 \
    --restrictionSequence ${restrictionSequence} \
    --danglingSequence ${danglingSequence} \
    --restrictionCutFile rest_site_positions.bed \
    --outFileName ${describer}_5kb.h5 \
    --QCfolder ${describer}_5kb_QC --threads 8
```

The ``--QCfolder`` output contains quality metrics that should be inspected before proceeding.

#### Multi-Resolution Matrix Generation 

- Merges to 10 kb, 20 kb, 50 kb, and 100 kb matrices.

#### KR Normalization and Format Conversion

All matrices (5, 10, 20, 50, 100 kb) are normalized using KR (Knight-Ruiz) balancing, applied per chromosome (``--perchr``). Normalized matrices are then converted from ``.h5`` to ``.cool`` format for compatibility with cooltools and downstream visualization.

####  Loop Calling (mustache)

Chromatin loops are called at 5, 10, and 20 kb resolution using mustache, at two p-value thresholds to allow flexible downstream filtering:

```bash
python -m mustache -f ${describer}_${res}kb_KR.cool \
    -r ${res}kb -pt 0.1  -o loops_01_${res}kb.tsv

python -m mustache -f ${describer}_${res}kb_KR.cool \
    -r ${res}kb -pt 0.05 -o loops_05_${res}kb.tsv  
```  

#### Cooltools analysis  

Here we use cooltools to obtaing the saddle plots, and visualize the compartment strenght, this is performed in three steps:

**1. Expected contacts** — Calculate expected Hi-C signal for cis regions of chromosomal interaction map

```bash
cooltools expected-cis -p 8 -o ${describer}_exp.tsv ${describer}_100kb_KR.cool
```
**2.Eigenvector decomposition** — Perform eigen value decomposition on a cooler matrix to calculate compartment signal by finding the eigenvector that correlates best with the phasing track.

```bash
cooltools eigs-cis --phasing-track ${ref_compartments} \
    -o ${describer}_100kb_KR_ev_ac ${describer}_100kb_KR.cool
```
EV1, EV2, and EV3 are each exported as individual bedgraph files for downstream use.

**3.Saddle Plot** — Calculate saddle statistics and generate saddle plots for an arbitrary signal track on the genomic bins of a contact matrix.

```bash
cooltools saddle --qrange 0.02 0.98 --strength \
    --vmin 0.2 --vmax 4 --fig pdf \
    ${describer}_100kb_KR.cool \
    ${describer}_ev_ac.cis.vecs.tsv \
    ${describer}_exp.tsv
```

> [!IMPORTANT]
> This script generates saddle plots using the cooltools eigenvectors computed in the previous step. However, saddle plots can also be generated using the compartment scores from the other two methods available in this pipeline.

#### TAD Calling

TADs are called at 20 kb resolution.

```bash
hicFindTADs -m ${describer}_20kb_KR.h5 \
    --minDepth 100000 --maxDepth 200000 --step 20000 \
    --thresholdComparisons 0.01 --delta 0.01 \
    --correctForMultipleTesting fdr -p 8
```


## Outputs

Once you run the pipeline, the following files and folders are generated:

| Directory | Primary File Types | Description |
| :--- | :--- | :--- |
| `TADs/` | `.bed`, `.gff`, `.bedgraph` | Topologically Associating Domain boundaries and scores. |
| `bamfiles/` | `.bam` | Cleaned read alignments. |
| `coolMatrix/` | `.cool` | Contact matrices optimized for HiGlass/Juicebox. |
| `cooltools/` | `.pdf`, `.npz`, `.tsv` | A/B compartment eigenvectors and saddle plot metrics. |
| `cscore/` | `.bedgraph`, `.txt` | Quantified genomic compartment status computed using c-score Tool. |
| `juicer/` | `.bedgraph` | Quantified genomic compartment status computed using JuicerTools. |
| `hicMatrix/` | `.h5`, `.html` | Processed interaction matrices and QC summaries. |
| `homer/` | `.tags.tsv` | Tag directories for HOMER compatibility. |
| `loops/` | `.bedpe` | Detected chromatin loop interactions. |







