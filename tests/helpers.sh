#!/bin/bash

set -euo pipefail

assert_equals() {
    local expected="${1-}"
    local actual="${2-}"
    local message="${3:-Expected '$expected' but got '$actual'}"

    if [ "$expected" != "$actual" ]; then
        echo "ASSERTION FAILED: $message" >&2
        exit 1
    fi
}

assert_contains() {
    local haystack="${1-}"
    local needle="${2-}"
    local message="${3:-Expected output to contain '$needle'}"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo "ASSERTION FAILED: $message" >&2
        exit 1
    fi
}

assert_success() {
    local message="${1:-Expected command to succeed}"

    if [ "$?" -ne 0 ]; then
        echo "ASSERTION FAILED: $message" >&2
        exit 1
    fi
}
