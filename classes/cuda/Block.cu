//
// Created by Dave Nash on 20/10/2017.
//

#include "../../headers/cuda/Block.cuh"
#include "../../headers/cuda/sha256_CPU.cuh"
#include "../../headers/cuda/sha256_GPU.cuh"

#define SOLUTION_LEN 25

__constant__ unsigned char setOfCharacter[63] = { "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890" };

Block::Block(uint32_t nIndexIn, const string &sDataIn) : _nIndex(nIndexIn), _sData(sDataIn)
{
    _sNonce = '0';
    _tTime = time(nullptr);

    sHash = _CalculateHash();
}

__global__ void createSolutionChecker(bool* block_isSolved){
    *block_isSolved = false;
}


__device__ unsigned long long generateRngSeed_GPU(unsigned long long x)
{
    x ^= (x << 21);
    x ^= (x >> 35);
    x ^= (x << 4);
    return x;
}


__global__ void SHA256_CUDA(unsigned char* input_string,unsigned char* solution, bool* block_isSolved,uint32_t nDifficulty,unsigned long long seed, size_t text_len){
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    unsigned long long newSeed = seed;
    newSeed = (unsigned long long) i + newSeed;

    unsigned char digest[32], random[SOLUTION_LEN];

    memset(digest, 0, SHA256::DIGEST_SIZE);
    memset(random, 0, SOLUTION_LEN);


    for(int j = 0; j < SOLUTION_LEN; j++){
        newSeed = generateRngSeed_GPU(newSeed);
        int randomIdx = (int)(newSeed % 62);
        random[j] = setOfCharacter[randomIdx];
    }

    SHA256GPU::sha256(input_string, random, text_len, SOLUTION_LEN, digest);

    for (int j = 0; j < nDifficulty; j++){
        if(digest[j] > 0){
            return;
        }
    }

    if(*block_isSolved){
        return;
    }

    *block_isSolved = true;
    
    for(int j = 0; j < SOLUTION_LEN; j++){
        solution[j] = random[j];
    }
}

void Block::generateRngSeed_CPU(unsigned long long* x)
{
    *x ^= (*x << 21);
    *x ^= (*x >> 35);
    *x ^= (*x << 4);
}

// OpenMP (GPU)
void Block::MineBlock(uint32_t nDifficulty)
{

    /**
     * @brief 
     * Para paralelizar o código da Blockchain utilizando CUDA na GPU, precisamos localizar a parte mais pesada do programa, que é 
     * justamente a mineração do bloco, mais especificamente no calculo do hash SHA256 que é feito até chegar em uma solução. Por isso,
     * vamos paralelizar esta parte. Para isso, a ideia que temos é de alocar um bloco na GPU para receber uma string que será utilizada 
     * na criptografia, um bloco onde estará contido o resultado da criptografia e um bloco para um valor booleano que será utilizado para 
     * checar se o resultado bate com a string original. Após encontrar a solução em GPU, que deve ser mais ágil que em CPU, devolveremos a 
     * resposta para a CPU que ira utilizar para criar o novo bloco.
     */

    uint32_t dimGrid = 1500, dimBlock = 256;

    stringstream str_stream;
    str_stream << _nIndex << _tTime << sPrevHash;

    string str_stream_str = str_stream.str();

    unsigned char* input_string = (unsigned char*)str_stream_str.c_str();
    unsigned char* d_input;

    unsigned char* block_solution = (unsigned char*)malloc(sizeof(char) * SOLUTION_LEN);
    unsigned char* d_solution;

    bool* block_isSolved = (bool*)malloc(sizeof(bool));
    bool* d_isSolved;

    //Alocação da memoria em GPU e copia para da string de input para a mesma
    cudaMalloc(&d_input, sizeof(char) * str_stream_str.length());
    cudaMemcpy(d_input, input_string, sizeof(char) * str_stream_str.length(), cudaMemcpyHostToDevice);
    
    //Alocação da memoria em GPU e copia da string que conterá a solução
    cudaMalloc(&d_solution, sizeof(char) * SOLUTION_LEN);

    //Alocação da memoria em GPU para o booleano
    cudaMalloc(&d_isSolved, sizeof(bool));

    //Seta o solução checker como falso inicialmente
    unsigned long long seed = static_cast<unsigned long long>(time(nullptr));
    createSolutionChecker<<<1,1>>>(d_isSolved);

    //Usa o SHA256 paralelizado para chegar na solução
    bool solution = false;
    while(!solution) {
        generateRngSeed_CPU(&seed);

        SHA256_CUDA<<<dimGrid, dimBlock>>>(d_input, d_solution, d_isSolved, nDifficulty, seed, str_stream_str.length());
        
        cudaDeviceSynchronize();

        cudaMemcpy(block_isSolved, d_isSolved, sizeof(int), cudaMemcpyDeviceToHost);

        if(*block_isSolved){
            cudaMemcpy(block_solution, d_solution, sizeof(char) * SOLUTION_LEN, cudaMemcpyDeviceToHost);
            solution = true;

            break;
        }
    }

    cudaDeviceReset();

    _sNonce = string((const char*)block_solution);
    sHash = _CalculateHash();
    
    cout << "Block mined: " << sHash << endl;
}

inline string Block::_CalculateHash() const
{
    stringstream ss;
    ss << _nIndex << sPrevHash << _tTime << _sData << _sNonce;
    
    return sha256(ss.str());
}


