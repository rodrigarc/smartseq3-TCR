#!/bin/bash

# Usage: ./trust4_run.sh Plate_1

set -euo pipefail

# ---------------------------------------------------------------------------- #
# Argument & Paths
if [ $# -lt 1 ]; then
	  echo "Usage: $0 <PLATE_NAME>"
	    exit 1
fi

PLATE_NAME=$1

TRIMMED_DIR="data/03_SS3_trimmed_fastq/${PLATE_NAME}/"
OUTPUT_DIR="data/05_SS3_trust4_assembled_cells/${PLATE_NAME}/"
DB_FA="data/databases/macaca_fascicularis/IMGT_C+KIMDB_HC+Cirelli_LC.fa"
SIF="./env/05_trust4_SS3.sif"
THREADS=20

# ---------------------------------------------------------------------------- #
# Check inputs
if [ ! -d "$TRIMMED_DIR" ]; then
	  echo "Error: Trimmed fastq directory not found: $TRIMMED_DIR"
	    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ---------------------------------------------------------------------------- #
# Create read list files in the OUTPUT_DIR
READ1_LIST="${OUTPUT_DIR}/read1_list.txt"
READ2_LIST="${OUTPUT_DIR}/read2_list.txt"

find "$TRIMMED_DIR" -type f -name "*_R1_*.fq.gz" | sort > "$READ1_LIST"
find "$TRIMMED_DIR" -type f -name "*_R2_*.fq.gz" | sort > "$READ2_LIST"

echo "Read 1 list saved to: $READ1_LIST"
echo "Read 2 list saved to: $READ2_LIST"

# ---------------------------------------------------------------------------- #
# Run TRUST4 using .sif directly (no --ref)
echo "Running TRUST4 on plate: $PLATE_NAME"

"$SIF" \
	  -1 "$READ1_LIST" \
	    -2 "$READ2_LIST" \
	      -f "$DB_FA" \
	        -o "${OUTPUT_DIR}/${PLATE_NAME}" \
		  -t "$THREADS"

echo "TRUST4 completed for $PLATE_NAME. Output in: $OUTPUT_DIR"

