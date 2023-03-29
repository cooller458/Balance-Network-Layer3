//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    AlreadyInit,
    HadZeroInit,
    NotOrigin,
    DataTooLarge,
    NotRollup,
    DelayedBackwards,
    DelayedTooFar,
    ForceIncludeBlockTooSoon,
    ForceIncludeTimeTooSoon,
    IncorrectMessagePreimage,
    NotBatchPoster,
    BadSequencerNumber,
    DataNotAuthenticated,
    AlreadyValidDASKeyset,
    NoSuchKeyset,
    NotForked
} from "../libraries/Error.sol";
import "./IBridge.sol";
import "./IInbox.sol";
import "./ISequencerInbox.sol";
import "../rollup/IRollupLogic.sol";
import "./Messages.sol";

import {L1MessageType_batchPostingReport} from "../libraries/MessageTypes.sol";
import {GasRefundEnabled, IGasRefunder} from "../libraries/IGasRefunder.sol";
import "../libraries/DelegateCallAware.sol";
import {MAX_DATA_SIZE} from "../libraries/Constants.sol";


contract SequencerInbox is DelegateCallAware, GasRefundEnabled , ISequencerInbox {
    uint256 public totalDelayedMessagesRead;
    IBridge public  bridge;
    uint256 public constant HEADER_LENGTH = 40;

    bytes1 public constant DATA_AUTHENTICATED_FLAG = 0x40;

    IOwnable public rollup;
    mapping(address => bool) public isBatchPoster;

    ISequencerInbox.MaxTimeVariation public maxTimeVariation;

    mapping(bytes32 => DasKeySetInfo) public dasKeysetInfo;

    modifier onlyRollupOwner() {
        if(msg.sender != rollup.owner()) revert NotOwner(msg.sender, address(rollup));
        _;
    }
    uint256 internal immutable deployTimeChainId = block.chainid;

    function _chainIdChanged() internal vew returns(bool) {
        return deployTimeChainId != block.chainid;
    }

    function initialize(
        IBridge bridge_,
        ISequencerInbox.MaxTimeVariation calldata maxTimeVariation_
    ) external onlyDelegated{
        if(bridge != IBrdige(address(0))) revert AlreadyInit();
        if(address(bridge_) == address(0)) revert HadZeroInit();

        bridge = bridge_;
        rollup = bridge_.rollup();
        maxTimeVariation = maxTimeVariation_;
    }
    function getTimeBounds() internal view virtual returns(TimeBounds memory) {
        TimeBounds memory bounds;
        if (block.timestamp > maxTimeVariation.delaySeconds) {
            bounds.minTimestamp = uint64(block.timestamp - maxTimeVariation.delaySeconds);
        }
        bounds.maxTimestamp = uint64(block.timestamp + maxTimeVariation.futureSeconds);
        if (block.number > maxTimeVariation.delayBlocks) {
            bounds.minBlockNumber = uint64(block.number - maxTimeVariation.delayBlocks);
        }
        bounds.maxBlockNumber = uint64(block.number + maxTimeVariation.futureBlocks);
        return bounds;
    }

    function removeDelayAfterFork() external {
        if (!_chainIdChanged()) revert NotForked();
        maxTimeVariation = ISequencerInbox.MaxTimeVariation(
            {delayBlocks: 1,
            futureBlocks: 1,
            delaySeconds: 1,
            futureSeconds: 1}
        );
    }
    function forceInclusion(
        uint256 _totalDelayedMessagesRead,
        uint8 kind,
        uint64[2] calldata l2BlockAndTime,
        uint256 baseFeeL2,
        address sender,
        bytes32 messageDataHash
    ) external {
        if(_totalDelayedMessagesRead <= totalDelayedMessagesRead) revert DelayedBackwards();
        bytes32 messageHash = Messages.messageHash(
            kind,
            sender,
            l2BlockAndTime[0],
            l2BlockAndTime[1],
            _totalDelayedMessagesRead,
            baseFeeL2,
            messageDataHash
        );
        if ( l2BlockAndTime[0] + maxTimeVariation.delayBlocks >= block.number) revert ForceIncludeBlockTooSoon();
        if ( l2BlockAndTime[1] + maxTimeVariation.delaySeconds >= block.timestamp) revert ForceIncludeTimeTooSoon();

        bytes32 prevDelayedAcc = 0;

        if(_totalDelayedMessagesRead > 1) {
            prevDelayedAcc = bridge.delayedInboxAccs(_totalDelayedMessagesRead - 2);
        }
        if (
            bridge.delayedInboxAccs(_totalDelayedMessagesRead - 1) != Messages.accumulateMessage(prevDelayedAcc, messageHash) 
        ) revert IncorrectMessagePreimage();
        (bytes32 dataHash, TimeBounds memory timeBounds) = formEmptyDataHash(
            _totalDelayedMessagesRead
        );
        uint256 __totalDelayedMessagesRead = _totalDelayedMessagesRead;
        uint256 prevSeqMsgCount = bridge.sequencerReportedSubMessageCount();
        uint256 newSeqMsgCount = prevSeqMsgCount +
            _totalDelayedMessagesRead -
            totalDelayedMessagesRead;
        (
            uint256 seqMessageIndex,
            bytes32 beforeAcc,
            bytes32 delayedAcc,
            bytes32 afterAcc
        ) = addSequencerL2BatchImpl(
                dataHash,
                __totalDelayedMessagesRead,
                0,
                prevSeqMsgCount,
                newSeqMsgCount
            );
        emit SequencerBatchDelivered(
            seqMessageIndex,
            beforeAcc,
            afterAcc,
            delayedAcc,
            totalDelayedMessagesRead,
            timeBounds,
            BatchDataLocation.NoData
        );
    }
}