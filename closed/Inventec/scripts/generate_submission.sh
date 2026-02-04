#!/bin/bash

set -e

: "${STAGING_DIR:=build/submission-staging}"
: "${SUBMISSION_DIR:=build/submission}"
: "${DIVISION:=closed}"
: "${SUBMITTER:=Inventec}"
: "${SYSTEM_ID:=P9000AG7_B200-SXM-180GBx8_TRT}"
: "${SCENARIO:=Offline}"
: "${INFERENCE_DIR:=build/inference}"

[[ $(ls ${STAGING_DIR}) != ${DIVISION} ]] && { echo Bad DIVISION; exit 1; }
[[ $(ls ${STAGING_DIR}/${DIVISION}) != ${SUBMITTER} ]] && { echo Bad SUBMITTER; exit 1; }
[[ $(ls ${STAGING_DIR}/${DIVISION}/${SUBMITTER}/results) != ${SYSTEM_ID} ]] && { echo Bad SYSTEM_ID; exit 1; }

SUBMITTER_DIR=${STAGING_DIR}/${DIVISION}/${SUBMITTER}
RESULTS_DIR=${SUBMITTER_DIR}/results

# SRC1: build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}
# SRC2: code/${benchmark}/*/README.md
# DST:  ${RESULTS_DIR}/${SYSTEM_ID}/${benchmark}/${SCENARIO}

# benchmark is llama2-70b-99, llama3.1-8b, llama3.1-405b, whisper, ...
for benchmark in $(ls ${RESULTS_DIR}/${SYSTEM_ID}); do
  [[ -f build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/${SYSTEM_ID}_${SCENARIO}.json ]] || { echo No measurements.json for ${benchmark}; exit 1; }
  [[ -f build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/mlperf.conf ]] || { echo No mlperf.conf for ${benchmark}; exit 1; }
  [[ -f build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/user.conf ]] || { echo No user.conf for ${benchmark}; exit 1; }
  [[ -f $(ls code/${benchmark}/*/README.md) ]] || { echo No README.md for ${benchmark}; exit 1; }
  cp build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/${SYSTEM_ID}_${SCENARIO}.json \
     ${RESULTS_DIR}/${SYSTEM_ID}/${benchmark}/${SCENARIO}/measurements.json
  cp build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/mlperf.conf \
     ${RESULTS_DIR}/${SYSTEM_ID}/${benchmark}/${SCENARIO}/mlperf.conf
  cp build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/user.conf \
     ${RESULTS_DIR}/${SYSTEM_ID}/${benchmark}/${SCENARIO}/user.conf
  cp $(ls code/${benchmark}/*/README.md) \
     ${RESULTS_DIR}/${SYSTEM_ID}/${benchmark}/${SCENARIO}/README.md
done

# copy src
mkdir -p ${SUBMITTER_DIR}/src
for benchmark in $(ls ${RESULTS_DIR}/${SYSTEM_ID}); do
  cp -r code/${benchmark} ${SUBMITTER_DIR}/src/
done

# copy documentation & systems
cp -r documentation ${SUBMITTER_DIR}
cp -r systems ${SUBMITTER_DIR}

# compliance testing
for benchmark in $(ls ${RESULTS_DIR}/${SYSTEM_ID}); do
  OUTPUT_DIR=${RESULTS_DIR}/${SYSTEM_ID}/${benchmark}/${SCENARIO}
  case ${benchmark} in
    llama*)
      python ${INFERENCE_DIR}/compliance/TEST06/run_verification.py \
        --compliance_dir ${OUTPUT_DIR}/accuracy \
	--output_dir ${OUTPUT_DIR} \
	--scenario ${SCENARIO}
      ;;
    whisper)
      python ${INFERENCE_DIR}/compliance/TEST01/run_verification.py \
	--results_dir ${OUTPUT_DIR} \
        --compliance_dir ${OUTPUT_DIR}/accuracy \
	--output_dir ${OUTPUT_DIR}
      ;;
    *)
      echo No compliance test for ${benchmark}!
      exit 1
      ;;
  esac
done

# generate the actual submission directory from the staged directory
rm -rf ${SUBMISSION_DIR}
python ${INFERENCE_DIR}/tools/submission/truncate_accuracy_log.py \
  --input ${STAGING_DIR} --submitter ${SUBMITTER} --output ${SUBMISSION_DIR}
python ${INFERENCE_DIR}/tools/submission/submission_checker/main.py \
  --input ${SUBMISSION_DIR} \
  --version $(cat VERSION) \
  --submitter ${SUBMITTER} 2>&1 | tee submission_checker_log.txt
mv submission_checker_log.txt ${SUBMISSION_DIR}/${DIVISION}/${SUBMITTER}/
mv summary.csv ${SUBMISSION_DIR}/${DIVISION}/${SUBMITTER}/
