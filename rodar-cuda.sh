num_blocks="${1}"
difficulty="${2}"

nvcc -O3 main.cu -std=c++11 classes/cuda/Block.cu classes/cuda/Blockchain.cu classes/cuda/sha256.cu -o blockchain-cuda 
time ./blockchain-cuda "${num_blocks}" "${difficulty}"
