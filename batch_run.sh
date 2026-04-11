#!/bin/bash
# Batch process GigaHands sequences for sharpa robot
# Usage: ./batch_run.sh [max_count]
#
# Data layout expected (example dataset mode):
#   example_datasets/raw/gigahand/object_poses/{participant}-{scene}-{seq_id}/
#   example_datasets/raw/gigahand/hand_poses/{participant}-{scene}-{seq_id}/
#
# For full GigaHands dataset, set USE_FULL_DATASET=1 and point GIGAHAND_DIR
# to the directory containing objectposes/ and handposes/.

set -e

ROBOT_TYPE=sharpa
DATASET_NAME=gigahand
HAND_TYPE=bimanual
MAX_COUNT=${1:-100}      # process at most N sequences (default 100)
LOG_DIR=logs/batch_sharpa
USE_FULL_DATASET=0       # set to 1 if using full GigaHands (not example format)
DATASET_DIR="$(pwd)/example_datasets"
GIGAHAND_RAW="${DATASET_DIR}/raw/gigahand"

mkdir -p "${LOG_DIR}"

# Collect all available sequences from object_poses/
mapfile -t SEQUENCES < <(
    ls "${GIGAHAND_RAW}/object_poses/" 2>/dev/null \
    | grep -E '^p[0-9]+-[a-z]+-[0-9]+$' \
    | sort
)

TOTAL=${#SEQUENCES[@]}
echo "Found ${TOTAL} sequences. Processing up to ${MAX_COUNT}."

SUCCESS=0
FAIL=0
SKIP=0

for SEQ in "${SEQUENCES[@]}"; do
    if [ "${SUCCESS}" -ge "${MAX_COUNT}" ]; then
        break
    fi

    # Parse participant, scene, data_id from sequence name like p36-tea-0010
    PARTICIPANT=$(echo "${SEQ}" | cut -d'-' -f1)
    SCENE=$(echo "${SEQ}" | cut -d'-' -f2)
    SEQ_ID=$(echo "${SEQ}" | cut -d'-' -f3)
    DATA_ID=$((10#${SEQ_ID}))   # strip leading zeros for integer
    TASK="${PARTICIPANT}-${SCENE}"
    LOG="${LOG_DIR}/${SEQ}.log"

    # Skip if already fully processed (trajectory_ikrollout.npz exists)
    DONE_MARKER="${DATASET_DIR}/processed/${DATASET_NAME}/${ROBOT_TYPE}/${HAND_TYPE}/${TASK}/trajectory_ikrollout.npz"
    if [ -f "${DONE_MARKER}" ]; then
        echo "[SKIP] ${SEQ} (already processed)"
        SKIP=$((SKIP + 1))
        continue
    fi

    echo "[RUN ] ${SEQ} (participant=${PARTICIPANT} scene=${SCENE} seq=${SEQ_ID} data_id=${DATA_ID})"

    (
        set -e

        # Step 1: process raw → mano keypoints
        echo "  [1/5] process_datasets..."
        uv run spider/process_datasets/gigahand.py \
            --participant="${PARTICIPANT}" \
            --scene="${SCENE}" \
            --embodiment-type="${HAND_TYPE}" \
            --sequence-id="${SEQ_ID}" \
            --no-show-viewer \
            --no-save-video \
            --dataset-dir="${DATASET_DIR}"

        # Step 2: decompose object mesh
        echo "  [2/5] decompose_fast..."
        uv run spider/preprocess/decompose_fast.py \
            --task="${TASK}" \
            --dataset-name="${DATASET_NAME}" \
            --data-id="${DATA_ID}" \
            --embodiment-type="${HAND_TYPE}" \
            --dataset-dir="${DATASET_DIR}"

        # Step 3: detect contact
        echo "  [3/5] detect_contact..."
        uv run spider/preprocess/detect_contact.py \
            --task="${TASK}" \
            --dataset-name="${DATASET_NAME}" \
            --data-id="${DATA_ID}" \
            --embodiment-type="${HAND_TYPE}" \
            --dataset-dir="${DATASET_DIR}"

        # Step 4: generate scene XML
        echo "  [4/5] generate_xml..."
        uv run spider/preprocess/generate_xml.py \
            --task="${TASK}" \
            --dataset-name="${DATASET_NAME}" \
            --data-id="${DATA_ID}" \
            --embodiment-type="${HAND_TYPE}" \
            --robot-type="${ROBOT_TYPE}" \
            --no-show-viewer \
            --dataset-dir="${DATASET_DIR}"

        # Step 5: IK
        echo "  [5/5] ik_fast..."
        uv run spider/preprocess/ik_fast.py \
            --task="${TASK}" \
            --dataset-name="${DATASET_NAME}" \
            --data-id="${DATA_ID}" \
            --embodiment-type="${HAND_TYPE}" \
            --robot-type="${ROBOT_TYPE}" \
            --dataset-dir="${DATASET_DIR}"

    ) > "${LOG}" 2>&1

    if [ $? -eq 0 ]; then
        echo "  [OK] ${SEQ}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "  [FAIL] ${SEQ} — see ${LOG}"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "===== Done: ${SUCCESS} ok, ${FAIL} failed, ${SKIP} skipped ====="
