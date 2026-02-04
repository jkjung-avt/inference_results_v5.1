#!/bin/bash

set -e

: "${STAGING_DIR:=build/submission-staging}"
: "${DIVISION:=closed}"
: "${ORGANIZATION:=Inventec}"
: "${SYSTEM_ID:=P9000AG7_B200-SXM-180GBx8_TRT}"
: "${SCENARIO:=Offline}"

[[ $(ls ${STAGING_DIR}) != ${DIVISION} ]] && { echo Bad DIVISION; exit 1; }
[[ $(ls ${STAGING_DIR}/${DIVISION}) != ${ORGANIZATION} ]] && { echo Bad ORGANIZATION; exit 1; }
[[ $(ls ${STAGING_DIR}/${DIVISION}/${ORGANIZATION}/results) != ${SYSTEM_ID} ]] && { echo Bad SYSTEM_ID; exit 1; }

# SRC1: build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}
# SRC2: code/${benchmark}/*/README.md
# DST:  ${STAGING_DIR}/${DIVISION}/${ORGANIZATION}/results/${SYSTEM_ID}/${benchmark}/${SCENARIO}

# benchmark is llama2-70b-99, llama3.1-8b, llama3.1-405b, whisper, ...
for benchmark in $(ls build/submission-staging/closed/Inventec/results/P9000AG7_B200-SXM-180GBx8_TRT); do
  [[ -f build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/${SYSTEM_ID}_${SCENARIO}.json ]] || { echo No measurements.json for ${benchmark}; exit 1; }
  [[ -f build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/mlperf.conf ]] || { echo No mlperf.conf for ${benchmark}; exit 1; }
  [[ -f build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/user.conf ]] || { echo No user.conf for ${benchmark}; exit 1; }
  [[ -f $(ls code/${benchmark}/*/README.md) ]] || { echo No README.md for ${benchmark}; exit 1; }
  cp build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/${SYSTEM_ID}_${SCENARIO}.json \
     ${STAGING_DIR}/${DIVISION}/${ORGANIZATION}/results/${SYSTEM_ID}/${benchmark}/${SCENARIO}/measurements.json
  cp build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/mlperf.conf \
     ${STAGING_DIR}/${DIVISION}/${ORGANIZATION}/results/${SYSTEM_ID}/${benchmark}/${SCENARIO}/mlperf.conf
  cp build/loadgen-configs/${SYSTEM_ID}/${benchmark}/${SCENARIO}/user.conf \
     ${STAGING_DIR}/${DIVISION}/${ORGANIZATION}/results/${SYSTEM_ID}/${benchmark}/${SCENARIO}/user.conf
  cp $(ls code/${benchmark}/*/README.md) \
     ${STAGING_DIR}/${DIVISION}/${ORGANIZATION}/results/${SYSTEM_ID}/${benchmark}/${SCENARIO}/README.md
done
