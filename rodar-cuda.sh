num_blocks="${1}"
difficulty="${2}"

nvcc -O3 main.cu -std=c++11 classes/Block.cu classes/Blockchain.cpp classes/sha256.cpp -o blockchain-cuda 
time ./blockchain-cuda "${num_blocks}" "${difficulty}"
