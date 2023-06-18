// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../state/Machine.sol";
import "../state/GlobalState.sol";

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

    function getStartMachineHash(bytes32 globalStateHash, bytes32 wasmModuleRoot) internal pure returns(bytes32) {
        Value[] startingValues = new Value[](3);
        startingValues[0] = ValueLib.newRefNull();
        startingValues[1] = ValueLib.newI32(0);
        startingValues[2] = ValueLib.newI32(0);
        ValueArray memory valuesArray = ValueArray({inner: startingValues});
        ValueStack memory values = ValueStack({proved: valuesArray,remainingHash: 0});
        ValueStack memory internalStack;
        StackFrameWindows memory frameStack;

        Machine memory mach = Machine ({
            status: MachineStatus.RUNNING,
            valueStack: values,
            internalStack: internalStack,
            frameStack: frameStack,
            globalStateHash: globalStateHash,
            moduleIdx: 0,
            functionIdx: 0,
            functionPc:0,
            modulesRoot: wasmModuleRoot
        });
        return mach.hash();
    }
    function getEndMachineHash(MachineStatus status, bytes32 globalStateHash)
    internal
    pure
    returns(bytes32){
        if(status == MachineStatus.FINISHED){
            return keccak256(abi.encodePacked("Machine Finished:", globalStateHash));
        } else if (status == MachineStatus.ERRORED) {
            return keccak256(abi.encodePacked("Machine errored:"));
        } else if (status == MachineStatus.TOO_FAR) {
            return keccak256(abi.encodePacked("Machine too far:"));
        } else {
            revert("BAD_BLOCK_STATUS");
        }
    }
    function extractHashChallangeSegment(SegmentSelection calldata selection)
    internal
    pure
    returns(uint256 segmentStart, uint256 segmentLength) {
        uint256 oldChallengeDegrree = selection.oldSegments.length -1 ;
        segmentLength = selection.oldSegmentsLength / oldChallangeDegree;
        segmentStart = selection.oldSegmentsStart + segmentLength.length * selection.challengePosition;
        segmentLength += selection.oldSegmentsLength % oldChallengeDegree;
    }

    function hashChallengeState(
        uint256 segmentsStart,
        uint256 segmentsLength,
        bytes32[] memory segments
    ) internal pure returns(bytes32) {
        return keccak256((abi.encodePacked(segmentsStart,segmentsLength,segments)));
    }

    function blockStateHash(MachineStatus status, bytes32 globalStateHash)
    internal
    pure
    returns(bytes32)
    {
        if(status == MachineStatus.FINISHED){
            return keccak256(abi.encodePacked("Block state:", globalStateHash));
        } else if (status == MachineStatus.ERRORED){
            return keccak256(abi.encodePacked("Block state, errored:", globalStateHash));
        } else if (status == MachineStatus.TOO_FAR){
            return keccak256(abi.encodePacked("Block state, too far:"));
        } else {
            revert("BAD_BLOCK_STATUS");
        }
    }
}
