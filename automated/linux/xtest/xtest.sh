#!/bin/bash

set -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
TMP_LOG="${OUTPUT}/tmp_log.txt"
TEST_PASS_LOG="${OUTPUT}/test_pass_log.txt"
TEST_FAIL_LOG="${OUTPUT}/test_fail_log.txt"
TEST_SKIP_LOG="${OUTPUT}/test_skip_log.txt"
export RESULT_FILE

TESTS=""
SKIP_TESTS=""
TEST_PROGRAM=xtest
TEST_PROG_VERSION=
TEST_GIT_URL=https://github.com/OP-TEE/optee_test.git
TEST_DIR="/bin"
SKIP_INSTALL="false"

usage() {
	echo "\
	Usage: [sudo] ./xtest.sh [-t <TESTS>]
				     [-v <TEST_PROG_VERSION>] [-u <TEST_GIT_URL>] [-p <TEST_DIR>]
				     [-s <true|false>]

	<TESTS>:
	Set of tests: 'throughput' benchmarks throughput, while
	'replayed-startup' benchmarks the start-up times of popular
	applications, by replaying their I/O. The replaying saves us
	from meeting all non-trivial dependencies of these applications
	(such as having an X session running). Results are
	indistinguishable w.r.t. to actually starting these applications.
	Default value: \"throughput replayed-startup\"

	<SKIP_TESTS>:
	Skip listed tests, e.g. s3,nx,method

	<TEST_PROG_VERSION>:
	If this parameter is set, then the ${TEST_PROGRAM} suite is cloned. In
	particular, the version of the suite is set to the commit
	pointed to by the parameter. A simple choice for the value of
	the parameter is, e.g., HEAD. If, instead, the parameter is
	not set, then the suite present in TEST_DIR is used.

	<TEST_GIT_URL>:
	If this parameter is set, then the ${TEST_PROGRAM} suite is cloned
	from the URL in TEST_GIT_URL. Otherwise it is cloned from the
	standard repository for the suite. Note that cloning is done
	only if TEST_PROG_VERSION is not empty

	<TEST_DIR>:
	If this parameter is set, then the ${TEST_PROGRAM} suite is cloned to or
	looked for in TEST_DIR. Otherwise it is cloned to $(pwd)/${TEST_PROGRAM}

	<SKIP_INSTALL>:
	If you already have it installed into the rootfs.
	default: false"
}

while getopts "h:t:k:p:u:v:s:" opt; do
	case $opt in
		t)
			TESTS="$OPTARG"
			;;
		k)
			SKIP_TESTS="--skip-test=$OPTARG"
			;;
		v)
			TEST_PROG_VERSION="$OPTARG"
			;;
		u)
			if [[ "$OPTARG" != '' ]]; then
				TEST_GIT_URL="$OPTARG"
			fi
			;;
		p)
			if [[ "$OPTARG" != '' ]]; then
				TEST_DIR="$OPTARG"
			fi
			;;
		s)
			SKIP_INSTALL="${OPTARG}"
			;;
		h)
			usage
			exit 0
			;;
		*)
			usage
			exit 1
			;;
	esac
done

install() {
	dist=
	dist_name
	echo "TODO: ${dist}! Package installation is not implemented!"
}

# Parse xtest test results
parse_xtest_test_results() {
	sed '1,/Result of testsuite regression+pkcs11/d' "${RESULT_LOG}" \
	| sed '1,/+-----------------------------------------------------/!d' \
	| head -n -1 \
	| grep -v "\." \
	| tee -a "${RESULT_FILE}"

	sed -i -e 's/OK/pass/' -e 's/FAILED/fail/' "${RESULT_FILE}"

	# Clean up
	#rm -rf "${TMP_LOG}" "${RESULT_LOG}" "${TEST_PASS_LOG}" "${TEST_FAIL_LOG}" "${TEST_SKIP_LOG}"
}

build_install_tests() {
	pushd "${TEST_DIR}" || exit 1
	autoreconf -ivf
	./configure --prefix=/
	make -j"$(nproc)" all
	make install
	popd || exit 1
}

run_test() {

	# Double quote to prevent globbing and word splitting.
	# In this case we don't want to add extra quote since that can make the
	# string get splitted.
	# shellcheck disable=SC2086
	xtest 2>&1 | tee -a "${RESULT_LOG}"
	parse_xtest_test_results
}

! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

# Install and run test

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
	info_msg "${TEST_PROGRAM} installation skipped altogether"
else
	install
fi

if ! (which xtest); then
	get_test_program "${TEST_GIT_URL}" "${TEST_DIR}" "${TEST_PROG_VERSION}" "${TEST_PROGRAM}"
	build_install_tests
fi
run_test "${TESTS}"
