# DeepSeek-R1

## Getting started

### Prepare and enter the mlperf container

Note that the mlperf inference needs to be run by a non-root user, say, "franklin".  You first need to make sure the user have access to docker.  This could be done by running the following command as root (replace "franklin" with your own account name).

   ```bash
   usermod -aG docker franklin
   ```

Then logout and re-login as "franklin", and set the scratch path environment variable.  All downloaded models/data and preprocessed data would be stored at this scratch space.

   ```bash
   export MLPERF_SCRATCH_PATH=/hps/franklin/mlperf_scratch
   ```

Run the prebuild command to build and enter the mlperf container.

   ```bash
   mkdir -p ${MLPERF_SCRATCH_PATH}/models ${MLPERF_SCRATCH_PATH}/data ${MLPERF_SCRATCH_PATH}/preprocessed_data
   cd ${HOME}/inference_results_v5.1/closed/Inventec
   make prebuild
   ```

This takes a long time (~2 hours) for the first time...  You should be inside the mlperf container when it finishes.  Then do the following within the mlperf container, which links the build/ directory to the scratch space.

   ```bash
   make link_dirs
   ls -al build/
   ```

You should see an output similar to the following.  (There might be other files in the build/ directory if you have previously built some code within the container.)

   ```
   total 4
   drwxrwxr-x  2 user group 4096 Jun 24 18:49 .
   drwxrwxr-x 15 user group 4096 Jun 24 18:49 ..
   lrwxrwxrwx  1 user group   35 Jun 24 18:49 data -> $MLPERF_SCRATCH_PATH/data
   lrwxrwxrwx  1 user group   37 Jun 24 18:49 models -> $MLPERF_SCRATCH_PATH/models
   lrwxrwxrwx  1 user group   48 Jun 24 18:49 preprocessed_data -> $MLPERF_SCRATCH_PATH/preprocessed_data
   ```

### Download Model

Please refer to [NVIDIA's README.me](https://github.com/jkjung-avt/inference_results_v5.1/blob/main/closed/NVIDIA/code/deepseek-r1/tensorrt/README.md) for various ways of downloading the deepseek-r1 model for MLPerf Inference benchmarking.

Specifically, to download the model, do the following directly _within the mlperf container_.

   ```bash
   mkdir -p build/models/deepseek-r1/fp4-quantized-modelopt
   bash <(curl -s https://raw.githubusercontent.com/mlcommons/r2-downloader/refs/heads/main/mlc-r2-downloader.sh) \
     -d build/models/deepseek-r1/deepseek-r1 \
     https://inference.mlcommons-storage.org/metadata/deepseek-r1-0528.uri
   git clone https://huggingface.co/nvidia/DeepSeek-R1-FP4-v2 build/models/deepseek-r1/fp4-quantized-modelopt/deepseek_r1-torch-fp4
   cd build/models/deepseek-r1/fp4-quantized-modelopt/deepseek_r1-torch-fp4/ && git checkout 4bedb8a695a119b1a38d16a675c4665e58708aea
   cd -
   cp code/deepseek-r1/tensorrt/hf_quant_config.json build/models/deepseek-r1/fp4-quantized-modelopt/deepseek_r1-torch-fp4/
   ```

### Download and Prepare Data
 
Do the following within the container to download and preprocess the data.

   ```bash
   mkdir -p build/data/deepseek-r1
   bash <(curl -s https://raw.githubusercontent.com/mlcommons/r2-downloader/refs/heads/main/mlc-r2-downloader.sh) \
     -d build/data/deepseek-r1 https://inference.mlcommons-storage.org/metadata/deepseek-r1-datasets-fp8-eval.uri
   ```
The preprocess script requires a newer version of numpy.  So we create a python virtual environment (venv) with the proper numpy module to do data preprocessing.

   ```bash
   python -m venv venv
   source venv/bin/activate  # enters the venv
   pip install numpy==2.3.0 torch==2.7.0 datasets==3.6.0
   python3 code/deepseek-r1/tensorrt/preprocess_data.py --data_dir build/data/ --preprocessed_data_dir build/preprocessed_data
   deactivate  # exits the venv
   ```

Make sure after the steps above, you have:

1. model downloaded at:
   - `build/models/deepseek-r1/deepseek-r1/` (original model)
   - `build/models/deepseek-r1/fp4-quantized-modelopt/deepseek_r1-torch-fp4/` (FP4 quantized model)
2. preprocessed data at `build/preprocessed_data/deepseek-r1/`:
   - `build/preprocessed_data/deepseek-r1/input_lens.npy`
   - `build/preprocessed_data/deepseek-r1/input_ids_padded.npy`
   - `build/preprocessed_data/deepseek-r1/mlperf_deepseek_r1_calibration_dataset_500_fp8_calibration/data.parquet`

## Build and run the benchmarks

Please follow the steps below in the mlperf container.  The build step would build code for all mlperf inference tasks, including code for other benchmarks.  If you are not running this benchmark for the first time and you did not make any modifications to the code since last `make build`, it suffices to just run `make build_loadgen` to save time.

   ```bash
   make build
   ```

Start the llm server.  Wait for a few seconds for the server to spin up (see logs).  Please note that all *performance* run (Offline/Server) needs to be measured using a fresh endpoint started by "run_llm_server".

   ```bash
   make run_llm_server RUN_ARGS="--core_type=trtllm_endpoint --benchmarks=deepseek-r1 --scenarios=Offline"
   ```

Validate accuracy of the model.

   ```bash
   make run_harness RUN_ARGS="--core_type=trtllm_endpoint --benchmarks=deepseek-r1 --scenarios=Offline --test_mode=AccuracyOnly"
   ```

Run the benchmark.

   ```bash
   make run_harness RUN_ARGS="--core_type=trtllm_endpoint --benchmarks=deepseek-r1 --scenarios=Offline"
   ```

To stop the endpoint, exit the container and re-enter again.
