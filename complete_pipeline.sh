#!/bin/bash
# ============================================================================ #
# complete_pipeline.sh                                                         #
# Author: Juan Sebastian Diaz Boada                                            #
# Edited by: Rodrigo Arcoverde                                                #
# ============================================================================ #

# Help function
function help {
  echo "Usage: $0 [OPTIONS] PLATE_NAME [NODES]"
  echo ""
  echo "Runs the Smart-seq3 TCR extraction pipeline for a given plate."
  echo "Assumes directory structure from https://github.com/scReumaKI/smartseq3-TCR"
  echo ""
  echo "Positional arguments:"
  echo "  PLATE_NAME               Name of the plate (prefix for input files/folders)."
  echo "  NODES                    Number of parallel jobs to use (default: 10)"
  echo ""
  echo "Options:"
  echo "  --stop-before-tracer     Run up to adapter trimming, then stop (skip TraCeR)."
  echo "  -h, --help                Show this help message and exit."
  exit 0
}

# Default values
STOP_BEFORE_TRACER=false

# Parse options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stop-before-tracer)
      STOP_BEFORE_TRACER=true
      shift
      ;;
    -h|--help)
      help
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

# Restore positional parameters
set -- "${POSITIONAL[@]}"

# Handle required positional arguments
if [ $# -lt 1 ]; then
  echo "Error: PLATE_NAME not provided." >&2
  exit 1
fi

PLATE_NAME=$1
NODES=${2:-10}
echo "Nodes = $NODES"

# ---------------------------------------------------------------------------- #
# Input validation
if [ ! -d data/00_SS3_raw_data/${PLATE_NAME}/ ]; then
  echo "Error: No raw data found for plate '${PLATE_NAME}'." >&2
  exit 1
fi

# ---------------------------------------------------------------------------- #
# 00. Container setup
echo "================================================================================="
./env/figlet.sif "0. Singularity"
echo "================================================================================="

for container in figlet 01_pysam_SS3 02_samtools_SS3 03_trimgalore_SS3; do
  if [ ! -f env/${container}.sif ]; then
    singularity build --fakeroot env/${container}.sif env/${container}.def
    echo "Built env/${container}.sif"
  else
    echo "Using existing container: env/${container}.sif"
  fi
done

# ---------------------------------------------------------------------------- #
# 01. Split BAM files
echo "================================================================================="
./env/figlet.sif "1. Pysam"
echo "================================================================================="

mkdir -p data/01_SS3_splitted_bams/${PLATE_NAME}/Aligned/
mkdir -p data/01_SS3_splitted_bams/${PLATE_NAME}/unmapped/

./env/01_pysam_SS3.sif \
data/00_SS3_raw_data/${PLATE_NAME}/${PLATE_NAME}.Xpress.filtered.Aligned.GeneTagged.UBcorrected.sorted.bam \
data/00_SS3_raw_data/${PLATE_NAME}/${PLATE_NAME}.barcodes.csv \
data/01_SS3_splitted_bams/${PLATE_NAME}/Aligned/ 

./env/01_pysam_SS3.sif \
data/00_SS3_raw_data/${PLATE_NAME}/${PLATE_NAME}.Xpress.filtered.tagged.unmapped.bam \
data/00_SS3_raw_data/${PLATE_NAME}/${PLATE_NAME}.barcodes.csv \
data/01_SS3_splitted_bams/${PLATE_NAME}/unmapped/ 

# ---------------------------------------------------------------------------- #
# 02. Merge and convert to fastq
echo "================================================================================="
./env/figlet.sif "2. Samtools"
echo "================================================================================="

mkdir -p data/02_SS3_merged_fastq/${PLATE_NAME}/

./env/02_samtools_SS3.sif \
data/01_SS3_splitted_bams/${PLATE_NAME}/ \
data/02_SS3_merged_fastq/${PLATE_NAME}/ $NODES

# ---------------------------------------------------------------------------- #
# 03. Trim adapters
echo "================================================================================="
./env/figlet.sif "3. TrimGalore!"
echo "================================================================================="

mkdir -p data/03_SS3_trimmed_fastq/${PLATE_NAME}/

./env/03_trimgalore_SS3.sif \
data/02_SS3_merged_fastq/${PLATE_NAME}/ \
data/03_SS3_trimmed_fastq/${PLATE_NAME}/ 8

# ---------------------------------------------------------------------------- #
# Optional: Exit early if user wants to skip TraCeR
if [ "$STOP_BEFORE_TRACER" = true ]; then
  echo "================================================================================="
  ./env/figlet.sif "Done: Stopped before TraCeR"
  echo "================================================================================="
  exit 0
fi

# ---------------------------------------------------------------------------- #
# Future steps (TraCeR + collection)
echo "================================================================================="
./env/figlet.sif "4. TraCeR + downstream (not implemented here)"
echo "================================================================================="
# Add TraCeR and analysis steps below here if needed in future


