#!/usr/bin/env bash
#set -o errexit

CMD_KUBECTL="kubectl"

${CMD_KUBECTL} delete ns policy-test 2>&1

