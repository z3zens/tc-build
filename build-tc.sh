#!/usr/bin/env bash

set -euo pipefail

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

# Set a directory
DIR="$(pwd ...)"

# Build Info
rel_date="$(date "+%Y%m%d")" # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format
builder_commit="$(git rev-parse HEAD)"

# Build LLVM
msg "Building LLVM..."
./build-llvm.py \
	--defines LLVM_PARALLEL_COMPILE_JOBS=$(nproc) LLVM_PARALLEL_LINK_JOBS=$(nproc) CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3 \
	--incremental \
	--no-update \
	--projects "clang;compiler-rt;polly" \
	--shallow-clone \
	--targets ARM AArch64 X86 \
	--vendor-string "z3zhain"

# Build binutils
msg "Building binutils..."
./build-binutils.py --targets arm aarch64 x86_64

# Remove unused products
echo "Removing unused products..."
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
echo "Stripping remaining products..."
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
    f="${f::-1}"
    echo "Stripping: $f"
    strip "$f"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
echo "Setting library load paths for portability..."
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
    # Remove last character from file output (':')
    bin="${bin::-1}"
    echo "$bin"
    patchelf --set-rpath "\$ORIGIN/../lib" "$bin"
done

# Release Info
echo "Release info..."
pushd llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< "$llvm_commit")"
popd || exit

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"

# Push to GitLab
echo "Push to gitlab..."
git config --global user.name "z3zens"
git config --global user.email "ramaadhananggay@gmail.com"
git clone "https://z3zens:$GL_TOKEN@gitlab.com/z3zens/clang-toolchains.git" rel_repo
cd rel_repo
cd $DIR
pushd rel_repo || exit
rm -fr ./*
cp -r ../install/* .
git checkout README.md && git checkout LICENSE # keep this as it's not part of the toolchain itself
git add .
git commit -asm "[$rel_date]: z3zhain LLVM Clang $clang_version

LLVM commit: $llvm_commit_url
Clang Version: $clang_version
Binutils version: $binutils_ver
Builder at commit: https://github.com/z3zens/tc-build/commit/$builder_commit"
git push -f
popd || exit
