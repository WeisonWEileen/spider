PARTICIPANT=p36
SCENE=tea
TASK=${PARTICIPANT}-${SCENE}
HAND_TYPE=bimanual
DATA_ID=10
ROBOT_TYPE=sharpa
DATASET_NAME=gigahand

# put your raw data under folder raw/{dataset_name}/ in your dataset folder

# read data from self collected dataset
uv run spider/process_datasets/gigahand.py --participant=${PARTICIPANT} --embodiment-type=${HAND_TYPE} --sequence-id=$(printf '%04d' ${DATA_ID}) --no-show-viewer

# # decompose object
# # here we use fast decompose pipeline with mink
# # you can also use decompose.py for original decompose pipeline with CoACD for higher quality decomposition
uv run spider/preprocess/decompose_fast.py --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE}

# # detect contact (optional)
uv run spider/preprocess/detect_contact.py --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE} --no-show-viewer

# # # generate scene
# uv run spider/preprocess/generate_xml.py --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE} --robot-type=${ROBOT_TYPE} --no-show-viewer

# # # # kinematic retargeting
# # # # here we use fast IK pipeline with mink=
# # # # you can also use ik.py for original ik pipeline with mujoco (used in paper)
# uv run spider/preprocess/ik_fast.py --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE} --robot-type=${ROBOT_TYPE}

# # # retargeting
# uv run examples/run_mjwp.py +override=${DATASET_NAME} task=${TASK} data_id=${DATA_ID} robot_type=${ROBOT_TYPE} embodiment_type=${HAND_TYPE}

# # # read data for deployment (optional)
# uv run spider/postprocess/read_to_robot.py --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} --robot-type=${ROBOT_TYPE} --embodiment-type=${HAND_TYPE}



















# ensure sync
cp example_datasets/processed/gigahand/assets/robots/sharpa/bimanual.xml spider/assets/robots/sharpa/bimanual.xml
cp example_datasets/processed/gigahand/assets/robots/sharpa/left.xml spider/assets/robots/sharpa/left.xml
cp example_datasets/processed/gigahand/assets/robots/sharpa/right.xml spider/assets/robots/sharpa/right.xml
