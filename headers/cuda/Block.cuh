//
// Created by Dave Nash on 20/10/2017.
//

#ifndef TESTCHAIN_BLOCK_H
#define TESTCHAIN_BLOCK_H

#include <cstdint>
#include <iostream>
#include <ctime>
#include <sstream>

using namespace std;

class Block {
public:
    string sHash;

    string sPrevHash;

    Block(uint32_t nIndexIn, const string &sDataIn);

    void MineBlock(uint32_t nDifficulty);

private:
    uint32_t _nIndex;
    string _sNonce;
    string _sData;
    time_t _tTime;

    string _CalculateHash() const;
};

#endif //TESTCHAIN_BLOCK_H
