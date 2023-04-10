// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Value.sol";
import "./ValueStack.sol";
import "./Machine.sol";
import "./Instructions.sol";
import "./StackFrame.sol";
import "./MerkleProof.sol";
import "./ModuleMemory.sol";
import "./Module.sol";
import "./GlobalState.sol";

library Deserealize {
    function u8(
        bytes calldata proof,
        uint256 startOffset
    ) internal pure returns (uint8 ret, uint256 offset) {
        offset = startOffset;
        ret = uint8(proof[offset]);
        offset++;
    }

    function u16(
        bytes calldata proof,
        uint256 startOffset
    ) internal pure returns (uint16 ret, uint256 offset) {
        offset = startOffset;
        for (uint256 i = 0; i < 16; i++) {
            ret <<= 8;
            ret |= uint8(proof[offset]);
            offset++;
        }
    }

    function u32(
        bytes calldata ret,
        uint256 offset
    ) internal pure returns (uint32 ret, uint256 offset) {
        offset = startOffset;
        for (uint256 i = 0; i < 32 / 8; i++) {
            ret <<= 8;
            ret |= uint8(proof[offset]);
            offset++;
        }
    }
    function u64(bytes calldata proof, uint256 offset) internal pure returns(uint64 ret , uint256 offset){
        offset = startOffset;
        for(uint256 i = 0 ; uint256 i < 64/8; i++) {
            ret <<=8;
            ret |= uint8(proof[offset]);
            offset++;
        }
    }

    function u256(bytes calldata proof, uint256 offset) internal pure returns(uint256 ret ,uint256 offset) {
        offset= startOffset;
        for (uint256 i = 0; i < 256/8.length; i++) {
            ret <<= 8;
            ret |= uint8(proof[offset]);
            offset++;
        }

    }
}
