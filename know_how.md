# Know-How: Running Spider with GigaHands Data (Sharpa Robot)

## 环境与依赖

### MANO Body Models 路径
`gigahand.py` 硬编码了 MANO 模型路径：
```python
model_path=f"{spider.ROOT}/../../GigaHands/body_models"
# 实际路径：/home/l/GigaHands/body_models/
```

**准备步骤**：
```bash
mkdir -p /home/l/GigaHands/body_models/smplh
cp /home/l/Downloads/mano_v1_2/models/MANO_LEFT.pkl /home/l/GigaHands/body_models/smplh/
cp /home/l/Downloads/mano_v1_2/models/MANO_RIGHT.pkl /home/l/GigaHands/body_models/smplh/
# J_regressor 文件已在 /home/l/GigaHands/body_models/ 中
```

### EasyMocap 与 chumpy 兼容性
`gigahand.py` 依赖 `easymocap`（未在 pyproject.toml 声明）。如遇报错：
```bash
# getargspec 已在 Python 3.11+ 删除
sed -i 's/inspect\.getargspec/inspect.getfullargspec/g' \
  .venv/lib/python3.12/site-packages/chumpy/ch.py

# NumPy 1.24+ 删除了类型别名
sed -i 's/from numpy import bool, int, float, complex, object, unicode, str, nan, inf/from numpy import nan, inf/' \
  .venv/lib/python3.12/site-packages/chumpy/__init__.py
```

## run.sh 变量设计

`TASK` 变量需要是完整任务名（participant + scene），各预处理脚本的 `--task` 参数都用它：

```bash
PARTICIPANT=p36
SCENE=tea
TASK=${PARTICIPANT}-${SCENE}   # = p36-tea
HAND_TYPE=bimanual
DATA_ID=10
ROBOT_TYPE=sharpa
DATASET_NAME=gigahand
```

`gigahand.py` 的 `--sequence-id` 需要 4 位零填充字符串（用于匹配原始数据文件夹 `p36-tea-0010`）：
```bash
--sequence-id=$(printf '%04d' ${DATA_ID})   # 10 → "0010"
```

---

## 各脚本 Bug 与修复

### 1. gigahand.py — 输出文件名错误
**问题**：保存为 `trajectory_kinematic.npz`，但 `detect_contact.py`、`ik_fast.py`、`generate_xml.py` 都读取 `trajectory_keypoints.npz`。

**修复**（`spider/process_datasets/gigahand.py`）：
```python
# 将两处 trajectory_kinematic.npz 改为：
f"{output_dir}/trajectory_keypoints.npz"
```

### 2. gigahand.py — 交互式 viewer 阻塞管道
`show_viewer=True` 默认值会打开 MuJoCo GUI，阻塞后续步骤。运行时需加：
```bash
--no-show-viewer
```
同理适用于 `detect_contact.py` 和 `generate_xml.py`。

### 3. decompose_fast.py — None 检查顺序错误 + 绝对路径拼接 Bug
**问题**：
```python
mesh_dir = task_info.get(mesh_dir_key)   # 可能为 None
mesh_dir = f"{dataset_path}/{mesh_dir}"   # None → ".../None"（字符串非空）
if not mesh_dir:                          # 永远不触发
```
**修复**（`spider/preprocess/decompose_fast.py`）：
```python
mesh_dir = task_info.get(mesh_dir_key)
if not mesh_dir:
    logger.warning("No mesh_dir for {} hand; skipping.", hand)
    continue
mesh_dir = os.path.join(str(dataset_path), mesh_dir)  # os.path.join 正确处理绝对路径
```

### 4. generate_xml.py — 绝对路径拼接 Bug
同 decompose_fast.py，四个路径变量都有相同问题。

**修复**（`spider/preprocess/generate_xml.py`）：
```python
right_convex_dir = task_info.get("right_object_convex_dir")
right_convex_dir = os.path.join(dataset_dir, right_convex_dir) if right_convex_dir else None
left_convex_dir  = task_info.get("left_object_convex_dir")
left_convex_dir  = os.path.join(dataset_dir, left_convex_dir) if left_convex_dir else None
right_mesh_dir   = task_info.get("right_object_mesh_dir")
right_mesh_dir   = os.path.join(dataset_dir, right_mesh_dir) if right_mesh_dir else None
left_mesh_dir    = task_info.get("left_object_mesh_dir")
left_mesh_dir    = os.path.join(dataset_dir, left_mesh_dir) if left_mesh_dir else None
```

### 5. task_info.json — 绝对路径 + 缺少 convex_dir
`gigahand.py` 早期版本存的是绝对路径，导致下游脚本找不到 mesh。

**正确格式**（`example_datasets/processed/gigahand/mano/bimanual/p36-tea/task_info.json`）：
```json
{
  "right_object_mesh_dir": "processed/gigahand/assets/objects/p36-tea",
  "right_object_convex_dir": "processed/gigahand/assets/objects/p36-tea/convex",
  "left_object_mesh_dir": null,
  "left_object_convex_dir": null
}
```
运行完 `decompose_fast.py` 后会自动写入 `right_object_convex_dir`，无需手动维护。

---

## Sharpa 机器人 — 缺少 IK Sites

**问题**：`sharpa/bimanual.xml` 没有 IK retargeting 所需的 sites（`right_palm`、`right_thumb_tip` 等），导致 `ik_fast.py` 报：
```
mink.exceptions.InvalidFrame: site 'right_palm' does not exist in the model.
```

**修复**：向 `example_datasets/processed/gigahand/assets/robots/sharpa/bimanual.xml` 中各手掌和指尖 body 添加 sites。

**Site 位置**（在各 DP body 局部坐标系中，由 MuJoCo 运动学计算）：
- 拇指（`*_thumb_DP`）：`pos="0.02 -0.001 0"`
- 其余四指（`*_{index/middle/ring/pinky}_DP`）：`pos="0.018 0 0"`
- 手掌（`*_hand_C_MC`）：`pos="0 0 0"`

每个指尖需添加 3 个 site（IK 目标 / 追踪约束 / 可视化 trace）：
```xml
<!-- 在 right_index_DP body 内，elastomer geom 之后 -->
<site name="right_index_tip"            pos="0.018 0 0" />
<site name="track_hand_right_index_tip" pos="0.018 0 0" />
<site name="trace_hand_right_index_tip" pos="0.018 0 0" />
```

手掌只需 1 个 site：
```xml
<!-- 在 right_hand_C_MC body 内 -->
<site name="right_palm" pos="0 0 0" type="box" size="0.01 0.02 0.03" quat="1 0 0 0" />
```

**注意**：`bimanual.xml` 是独立的完整文件（不 include right.xml/left.xml），必须直接编辑它。`right.xml` 和 `left.xml` 是单手独立使用的版本，也需同步更新。

---

## Sharpa 机器人 — 缺少 collision_hand_* geom（物理优化发散）

**问题**：`run_mjwp.py` 物理优化完全发散，轨迹飘动。

**根因**：`generate_xml.py` 通过扫描 `collision_hand_*` 前缀的 geom 来建立手-物体的 explicit contact pair（第 569-573 行）。Sharpa 的 `bimanual.xml` 只有 mesh collision geom，但命名为 `left_thumb_DP` 等，不符合规范，导致扫描到 0 个 geom，因此生成的 scene.xml 里手-物体之间有 **0 个 contact pair**。

此外，`generate_xml.py` 创建 object geom 时设置 `contype=0`，MuJoCo 的隐式碰撞也完全失效，物体可以自由穿透手掌。

**修复**：在 `bimanual.xml` 的各 finger body 中添加 capsule/box collision geom，命名规范为：
```
collision_hand_{side}_{finger}_{index}   # index: 0=末端, 1=近端
```

具体添加（每手 11 个，共 22 个）：
- `*_hand_C_MC` body：`collision_hand_{side}_palm_0`（box，`size="0.025 0.035 0.045" pos="0 0 0.04"`）
- `*_thumb_PP` body：`collision_hand_{side}_thumb_1`（capsule，`fromto="0 0 0 0.035 0 0" size="0.010"`）
- `*_thumb_DP` body：`collision_hand_{side}_thumb_0`（capsule，`fromto="0 0 0 0.018 0 0" size="0.009"`）
- `*_{finger}_PP` body（index/middle/ring/pinky）：`collision_hand_{side}_{finger}_1`（capsule，`fromto="0 0 0 0.04 0 0" size="0.010"`）
- `*_{finger}_DP` body：`collision_hand_{side}_{finger}_0`（capsule，`fromto="0 0 0 0.015 0 0" size="0.008"`）

**修复后效果**：`generate_xml.py` 输出从 "0 contact pairs" → **494 contact pairs**，物理优化不再发散。

**每次修改 bimanual.xml 后需重新运行**：
```bash
uv run spider/preprocess/generate_xml.py \
  --task=${TASK} --dataset-name=${DATASET_NAME} \
  --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE} \
  --robot-type=${ROBOT_TYPE} --no-show-viewer
```

---

## 完整工作流程

```bash
PARTICIPANT=p36
SCENE=tea
TASK=${PARTICIPANT}-${SCENE}
HAND_TYPE=bimanual
DATA_ID=10
ROBOT_TYPE=sharpa
DATASET_NAME=gigahand

# Step 1: 处理原始数据 → trajectory_keypoints.npz
uv run spider/process_datasets/gigahand.py \
  --participant=${PARTICIPANT} --embodiment-type=${HAND_TYPE} \
  --sequence-id=$(printf '%04d' ${DATA_ID}) --no-show-viewer

# Step 2: 凸分解 object mesh → convex/*.obj，更新 task_info.json
uv run spider/preprocess/decompose_fast.py \
  --task=${TASK} --dataset-name=${DATASET_NAME} \
  --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE}

# Step 3: 检测接触点（可选）→ 写回 trajectory_keypoints.npz
uv run spider/preprocess/detect_contact.py \
  --task=${TASK} --dataset-name=${DATASET_NAME} \
  --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE} --no-show-viewer

# Step 4: 生成机器人 scene.xml / scene_eq.xml
uv run spider/preprocess/generate_xml.py \
  --task=${TASK} --dataset-name=${DATASET_NAME} \
  --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE} \
  --robot-type=${ROBOT_TYPE} --no-show-viewer

# Step 5: 运动学 IK retargeting → trajectory_kinematic.npz
uv run spider/preprocess/ik_fast.py \
  --task=${TASK} --dataset-name=${DATASET_NAME} \
  --data-id=${DATA_ID} --embodiment-type=${HAND_TYPE} \
  --robot-type=${ROBOT_TYPE}

# Step 6: 物理优化 retargeting（GPU 加速）→ trajectory_mjwp.npz
uv run examples/run_mjwp.py \
  +override=${DATASET_NAME} task=${TASK} data_id=${DATA_ID} \
  robot_type=${ROBOT_TYPE} embodiment_type=${HAND_TYPE}

# Step 7: 部署数据读取（可选，交互式 viewer）
uv run spider/postprocess/read_to_robot.py \
  --task=${TASK} --dataset-name=${DATASET_NAME} --data-id=${DATA_ID} \
  --robot-type=${ROBOT_TYPE} --embodiment-type=${HAND_TYPE}
```
