# Hi-C Pipeline
This repository contains a complete Hi-C data processing pipeline for generating and analyzing chromatin contact maps. The workflow covers quality control, trimming, restriction site processing, read alignment, matrix generation, loop calling, compartment analysis, and additional downstream analyses.

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#before-starting">Before Starting</a>
      <ul>
        <li><a href="#prepare-the-samplestxt-file">Prepare the samples.txt file</a></li>
        <li><a href="#edit-the-configsh-file">Edit the config.sh file</a></li>
      </ul>
    </li>
    <li>
      <a href="#how-to-run-the-pipeline">How to Run the Pipeline</a>
    </li>
    <li>
      <a href="#step-by-step-description">Step-by-Step Description</a>
      <ul>
        <li><a href="#1-quality-control-and-trimming">1. Quality Control and Trimming</a>
          <ul>
            <li><a href="#fastqc">FastQC</a></li>
            <li><a href="#trim-galore">Trim Galore</a></li>
            <li><a href="#hicup-truncater">HICUP Truncater</a></li>
            <li><a href="#bowtie2-alignment">Bowtie2 Alignment</a></li>
          </ul>
        </li>
        <li><a href="#2-generate-txt-hi-c-files-txtfilesh">2. Generate .txt Hi-C files (txtfile.sh)</a></li>
        <li><a href="#3-cscore-analysis-cscoresh">3. Cscore Analysis (cscore.sh)</a></li>
        <li><a href="#4-hi-c-matrix-generation-and-analysis-hicexplorersh">4. Hi-C Matrix Generation and Analysis (hicexplorer.sh)</a></li>
      </ul>
    </li>
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

HICUP_trunc='../bin/hiCUP/HiCUP-0.9.2/hicup_truncater'  # Script used to truncate Hi-C reads at restriction sites. (required)
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

```

### 3. Load Required modules
++

## How to run the pipeline

Only the first script needs to be run manually.

```bash
sbatch --array=1-N scripts/HIC_PIPELINE.sh
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

### 2. Create HOMER Tag Directories and Generate Hi-C Files (tagdir.sh)
- This step converts aligned Hi-C reads (SAM files) into **HOMER tag directories**.
  - Tag directories are HOMER’s internal data format that store mapped read positions in a structured way, making them ready for Hi-C specific processing and analysis.
- From the tag directories, this step produces Hi-C interaction text files.
- These .txt files summarize contact frequencies between genomic loci and serve as the input for Cscore analysis.

*This analysis is divided un different steps:*

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

### 4. Cscore analysis (cscore.sh)
- This step calculates compartment scores (C-scores) from Hi-C data. C-scores quantify large-scale chromatin organization by identifying A/B compartments, which are associated with transcriptional activity (A) or inactivity (B). The script takes as input Hi-C interaction text files (produced from HOMER tag directories) and outputs compartment score values along the genome.

```bash
CscoreTool1.1 ${genome100kb} \
    homertxt_${array_id}.txt \
    sample1 \
    4 1000000
```

- ```${genome100kb}``` → Genome binning file at 100 kb resolution
- ```homertxt_${array_id}.txt``` → Hi-C interaction text file generated from the previous step
- ```sample1``` → Output prefix and directory for results
- ```4``` → Number of processing threads
- ```1000000``` → Window size (1 Mb) for calculating correlation patterns

Output Files:

### 5. Hi-C matrix generation and analysis (hicexplorer.sh)
- Finds restriction sites in the reference genome.
- Builds raw contact matrices at 5 kb resolution.
- Merges to 10 kb, 20 kb, 50 kb, and 100 kb matrices.
- Applies KR normalization and converts to .cool format.
- Calls loops at multiple resolutions with mustache.
- Computes expected contacts, eigenvectors, and compartment scores with cooltools.
- Generates saddle plots.
Output Files
