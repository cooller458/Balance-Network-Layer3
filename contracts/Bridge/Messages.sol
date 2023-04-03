//SPDX-License-Identifier: MIT

pragma solidity >=0.4.21 <0.9.0;

library Messages {
    function messageHash(
        uint8 kind,
        address sender,
        uint64 blockNumber ,
        uint64 timestamp,
        uint256 inboxSeqNum,
        uint256 baseFeeL2,
        bytes32 messageDataHash
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            kind,
            sender,
            blockNumber,
            timestamp,
            inboxSeqNum,
            baseFeeL2,
            messageDataHash
        ));
    }
    function accumulateInboxMessage(bytes32 prevAcc , bytes32 message) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(prevAcc, message));
    }
}