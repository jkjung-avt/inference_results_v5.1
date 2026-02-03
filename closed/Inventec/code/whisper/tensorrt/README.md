# Whisper Benchmarks

## Prepare and enter the mlperf container

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

## Prepare Whisper Model

If you have not built the code before, do it once.  Otherwise, just do `make build_loadgen`.

   ```bash
   make build
   ```
Download the model.  The model would be saved at `build/models/whisper-large-v3/`.

   ```bash
   bash -x /work/code/whisper/tensorrt/download_models.sh
   ```

Verify the downloaded model.

   ```bash
   $ tree /work/build/models/whisper-large-v3/
   /work/build/models/whisper-large-v3/
   ├── large-v3.pt
   ├── mel_filters.npz
   └── multilingual.tiktoken
   ```

## Preprocess Dataset

Run the following commands to preprocess the Whisper dataset, which involes:

1. Download the LibriSpeech `dev-clean` and `dev-other` datasets into `build/data/whisper-large-v3/LibriSpeech/`.
2. Pre-pack the audio files into `build/preprocessed_data/whisper-large-v3/dev-all-repack/`.
3. Generate a manifest file at `build/preprocessed_data/whisper-large-v3/dev-all-repack.json`.

   ```bash
   cp build/inference/speech2text/utils/inference_librispeech.csv /work/code/whisper/tensorrt/utils/inference_librispeech.csv
   source .llm_x86_64/bin/activate
   BENCHMARKS="whisper" make preprocess_data
   deactivate
   ```

## Generate Checkpoint and Generate Engines

Generate engines.

   ```bash
   make generate_engines RUN_ARGS="--benchmarks=whisper --scenarios=Offline"
   ```

The checkpoint directory `build/models/whisper-large-v3/whisper_large_v3_float16_weight_ckt/` should be:

   ```
   $ tree build/models/whisper-large-v3/whisper_large_v3_float16_weight_ckt/
   build/models/whisper-large-v3/whisper_large_v3_float16_weight_ckt/
   ├── decoder
   │   ├── config.json
   │   └── rank0.safetensors
   ├── encoder
   │   ├── config.json
   │   └── rank0.safetensors
   ├── stderr.txt
   └── stdout.txt
   
   3 directories, 6 files
   ```

The engine directory `/work/build/engnines/<Your Hardware Plateform>/whisper/*/`:

   ```bash
   ├── decoder
   │   ├── config.json
   │   ├── rank0.engine
   │   ├── stderr.txt
   │   └── stdout.txt
   └── encoder
       ├── config.json
       ├── rank0.engine
       ├── stderr.txt
       └── stdout.txt
   
   3 directories, 8 files
   ```
## Accuracy Test

Run an accuracy test.

   ```bash
   make run_harness RUN_ARGS="--benchmarks=whisper --scenarios=Offline --test_mode=AccuracyOnly"
   ```

An example result for B200x8 looks like this.

   ```
   Word Error Rate: 2.173644089572409%, accuracy=97.8263559104276%
   
   ======================== Result summaries: ========================
   
   Offline Scenario:
   +-------------------------------+-------------+-----------+------------------+---------------+------------------+-------------+
   | System Name                   | Benchmark   | Setting   | All Acc. Pass?   | Metric Name   |   Measured Value | Threshold   |
   +===============================+=============+===========+==================+===============+==================+=============+
   | P9000AG7_B200-SXM-180GBx8_TRT | whisper     | cp990     | Yes              | ACCURACY      |            97.83 | >=96.953571 |
   +-------------------------------+-------------+-----------+------------------+---------------+------------------+-------------+
   ```

## Performance Test

To run a performance test, use the following command.

   ```bash
   make run_harness RUN_ARGS="--benchmarks=whisper --scenarios=Offline --verbose --test_mode=PerformanceOnly"
   ```
