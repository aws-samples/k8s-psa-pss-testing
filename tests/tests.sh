#!/usr/bin/env bash
#set -o errexit

NEWLINE=$'\n'
CMD_KUBECTL="kubectl"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PREFIX="$SCRIPT_DIR/"
#clear

${CMD_KUBECTL} apply -f ${PREFIX}0-ns.yaml

echo "${NEWLINE}"

echo ">>> 1. Good config..."
${CMD_KUBECTL} apply -f ${PREFIX}1-ok.yaml
sleep 2
${CMD_KUBECTL} delete -f ${PREFIX}1-ok.yaml
sleep 2

echo "${NEWLINE}"

echo ">>> 2. Deployment - Missing container security context element..."
${CMD_KUBECTL} apply -f ${PREFIX}2-dep-sec-cont.yaml
sleep 2

echo "${NEWLINE}"

echo ">>> 3. Pod - Missing container security context element..."
${CMD_KUBECTL} apply -f ${PREFIX}3-pod.yaml
sleep 2

echo "${NEWLINE}"

echo ">>> 4. Pod - Pod security context, but Missing container security context element..."
${CMD_KUBECTL} apply -f ${PREFIX}4-pod.yaml
sleep 2

echo "${NEWLINE}"

echo ">>> 5. Pod - Container security context element present, with incorrect settings..."
${CMD_KUBECTL} apply -f ${PREFIX}5-pod.yaml
sleep 2

echo "${NEWLINE}"

echo ">>> 6. Pod - Container security context element present, with incorrect spec.hostNetwork, spec.hostPID, spec.hostIPC settings..."
${CMD_KUBECTL} apply -f ${PREFIX}6-pod.yaml
sleep 2

echo "${NEWLINE}"


















