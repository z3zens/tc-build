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
	--clang-vendor "Wurtzite" \
	--projects "clang;compiler-rt;polly" \
	--no-update \
	--targets "ARM;AArch64;X86"

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
pushd llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< "$llvm_commit")"
popd || exit

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"

# Push to GitHub
# Update Git repository
git config --global user.name z3zens
git config --global user.email "ramaadhananggay@gmail.com"
git clone "https://z3zens:$GL_TOKEN@wurtzite-toolchains" rel_repo
pushd rel_repo || exit
rm -fr ./*
cp -r ../install/* .
git checkout README.md # keep this as it's not part of the toolchain itself
git add .
git commit -asm "[$rel_date]: Wurtzite LLVM Clang 16.0.0

LLVM commit: $llvm_commit_url
Clang Version: $clang_version
Binutils version: $binutils_ver
Builder at commit: https://tc-build/commit/$builder_commit"
git push -f
popd || exit
