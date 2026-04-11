set -e

PARTICIPANT=p52
SCENE=instrument
TASK=${PARTICIPANT}-${SCENE}
HAND_TYPE=bimanual
DATA_ID=34

# PARTICIPANT=p44
# SCENE=dog
# TASK=${PARTICIPANT}-${SCENE}
# HAND_TYPE=bimanual
# DATA_ID=4

ROBOT_TYPE=sharpa
DATASET_NAME=gigahand

# PARTICIPANT=p44
# SCENE=dog
# TASK=${PARTICIPANT}-${SCENE}
# HAND_TYPE=bimanual
# DATA_ID=4


# uv run spider/process_datasets/gigahand.py --participant=${PARTICIPANT} --scene=${SCENE} --embodiment-type=${HAND_TYPE} --sequence-id=$(printf '%04d' ${DATA_ID}) --no-show-viewer
# uv run spider/preprocess/decompose_fast.py --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE}
# uv run spider/preprocess/detect_contact.py --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE}  --no-show-viewer

# # # # # generate scene (act mode: also produces scene_act.xml with object actuators)
# # # # echo "==============================Generating scene..."
# uv run spider/preprocess/generate_xml.py --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE} --robot-type=${ROBOT_TYPE} --no-show-viewer --act-scene

# # # # kinematic retargeting (use ik.py, not ik_fast.py — only ik.py supports --act-scene)
# # # echo "===============================Kinematic retargeting..."
# uv run spider/preprocess/ik.py --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE} --robot-type=${ROBOT_TYPE} --act-scene

# # retargeting with contact guidance
# echo "===============================Retargeting..."
uv run examples/run_mjwp.py +override=gigahand_act task=${TASK} data_id=${DATA_ID} robot_type=${ROBOT_TYPE} embodiment_type=${HAND_TYPE} viewer=mujoco
# # read data for deployment (optional)
# echo "===============================Reading data for deployment..."
# uv run spider/postprocess/read_to_robot.py --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} --robot-type=${ROBOT_TYPE} --embodiment-type=${HAND_TYPE}

# # ensure sync
# cp example_datasets/processed/gigahand/assets/robots/sharpa/bimanual.xml spider/assets/robots/sharpa/bimanual.xml
# cp example_datasets/processed/gigahand/assets/robots/sharpa/left.xml spider/assets/robots/sharpa/left.xml
# cp example_datasets/processed/gigahand/assets/robots/sharpa/right.xml spider/assets/robots/sharpa/right.xml
