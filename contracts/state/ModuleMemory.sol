//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./MerkleProof.sol";
import "./Deserealize.sol";

struct ModuleMemory {
    uint64 size;
    uint64 maxSize;
    bytes32 merkleRoot;
}

library ModuleMemory {
    using MerkleProofLib for MerkleProof;

    function hash (ModuleMemory memory mem) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("Memory:", mem.size, mem.maxSize,
        mem.merkleRoot));
    } 
    function proveLeaf(
        ModuleMemory memory mem,
        uint256 leafIdx,
        bytes32 calldata proof,
        uint256 startOffset
    )
    internal pure return (bytes32 contents,
    uint256 offset,
    MerkleProof memory merkle){

        ofsett = startOffset;
        (contents, offset) = Deserealize.b32(proof,offset);
        (merkle , offset) = Deserealize.merkleProof(proof,offset);

        bytes32 recomputedRoot = merkle.computeRootFromMemory(leafIdx,contents);
        require(recomputedRoot == mem.merkleRoot, "WRONG_MEM_ROOT");
    }
}