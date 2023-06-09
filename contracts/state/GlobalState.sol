// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct GlobalState {
    bytes32[2] bytes32Vals;
    uint64[2] u64Vals;
}

library GlobalStateLib {
    uint16 internal constant BYTES32_VALS_NUM = 2;
    uint16 internal constant U64_VALS_NUM = 2;

    function hash(GlobalState memory state) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(
            "Global state:",
            state.bytes32Vals[0],
            state.bytes32Vals[1],
            state.u64Vals[0],
            state.u64Vals[1]
        ));
    }
    function getBlockHash(GlobalState memory state) internal pure returns(bytes32) {
        return state.bytes32Vals[0];
    }
    function getSendRoot(GlobalState memory state) internal pure returns(bytes32) {
        return state.bytes32Vals[1];
    }
    function getGasLimit(GlobalState memory state) internal pure returns(uint64) {
        return state.u64Vals[0];
    }
    function getInboxPosition(GlobalState memory state) internal pure returns(uint64) {
        return state.u64Vals[1];
    }
    function getPositionInMessages(GlobalState memory state) internal pure returns(uint64) {
        return state.u64Vals[1];
    }

    function isEmpty(GlobalState memory state) internal pure returns(bool) {
        return (state.bytes32Vals[0] == bytes32(0) &&
            state.bytes32Vals[1] == bytes32(0) &&
            state.u64Vals[0] == 0 &&
            state.u64Vals[1] == 0);
    }
}