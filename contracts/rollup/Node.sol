//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct Node {
    bytes32 stateHash;

    bytes32 challengeHash;

    bytes32 confimrData;

    uint64 prevNum;

    uint64 deadlineBlock;

    uint64 noChildConfirmedBeforeBlock;

    uint64 stakerCount;

    uint64 childStakerCount;

    uint64 firstChildBlock;

    uint64 latestChildNumber;

    uint64 createdAtBlock;

    bytes32 nodeHash;

}

library NodeLib {
    function createNode(
        bytes32 _stateHash,
        bytes32 _challengeHash,
        bytes32 _confirmData,
        uint64 _prevNum,
        uint64 _deadlineBlock,
        bytes32 _nodeHash
    )internal view returns(Node memory) {
        Node memory node;
        node.stateHash = _stateHash;
        node.challengeHash = _challengeHash;
        node.confimrData = _confirmData;
        node.prevNum = _prevNum;
        node.deadlineBlock = _deadlineBlock;
        node.noChildConfirmedBeforeBlock = _deadlineBlock;
        node.createdAtBlock = uint64(block.number);
        node.nodeHash = _nodeHash;
        return node;
    }

    function childCreated(Node storage self, uint64 number) internal {
        if(self.firstChildBlock == 0) {
            self.firstChildBlock = uint64(block.number);
        }
        self.latestChildNumber = number;
    }

    function newChildConfirmDeadline(Node storage self, uint64 deadline) internal {
        self.noChildConfirmedBeforeBlock = deadline;
    }
    function requirePastDeadline(Node memory self) internal view {
        require(block.number >= self.deadlineBlock, "BEFORE_DEADLINE");
    }

    function requirePastChildConfirmDeadline(Node memory self) internal view {
        require(block.number >= self.noChildConfirmedBeforeBlock, "CHILD_TOO_RECENT");
    }
}