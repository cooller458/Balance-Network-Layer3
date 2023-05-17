// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../state/Machine.sol";
import "../state/GlobalState.sol";4

library ChallangeLib {
    using MachineLib for Machine;
    using ChallangeLib for Challange;

    enum ChallangeMode {
        NONE,
        BLOCK,
        EXECUTION
    }

    struct Participant {
        address addr;
        uint256 timeLeft;
    }

    struct Challange {
        Participant current;
        Participant next;
        uint256 lastMoveTimestamp;
        bytes32 wasmModuleRoot;
        bytes32 challengeStateHash;
        uint64 maxInboxMessages;
        ChallengeMode mode;
    }
    struct SegmentSelection {
        uint256 oldSegmentsStart;
        uint256 oldSegmentsLength;
        bytes32[] oldSegments;
        uint256 challangePosition;
    }

    function timeUsedSinceLastMove(Challange storage challenge) internal view returns(uint256) {
        return block.timestamp - challange.lastMoveTimestamp;
    }

    function isTimedOut(Challange storage challenge) internal view returns(bool) {
        return challange.timeUsedSinceLastMove() > challange.current.timeLeft;
    }

    function getStartMAchineHash(bytes32 globalStateHash, bytes32 wasmModuleRoot) internal pure returns(bytes32) {
        Value[] memory startingValues = new Value[](3);
        startingValues[0] = ValueLib.newRefNull();
        statingValues[1] = ValueLib.newI32(0);
        startingValues[1] = ValueLib.newI32(0);
        ValueArray memory stac
    }
}
