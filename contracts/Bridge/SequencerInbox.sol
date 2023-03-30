//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AlreadyInit, HadZeroInit, NotOrigin, DataTooLarge, NotRollup, DelayedBackwards, DelayedTooFar, ForceIncludeBlockTooSoon, ForceIncludeTimeTooSoon, IncorrectMessagePreimage, NotBatchPoster, BadSequencerNumber, DataNotAuthenticated, AlreadyValidDASKeyset, NoSuchKeyset, NotForked} from "../libraries/Error.sol";
import "./IBridge.sol";
import "./IInbox.sol";
import "./ISequencerInbox.sol";
import "../rollup/IRollupLogic.sol";
import "./Messages.sol";

import {L1MessageType_batchPostingReport} from "../libraries/MessageTypes.sol";
import {GasRefundEnabled, IGasRefunder} from "../libraries/IGasRefunder.sol";
import "../libraries/DelegateCallAware.sol";
import {MAX_DATA_SIZE} from "../libraries/Constants.sol";

contract SequencerInbox is
    DelegateCallAware,
    GasRefundEnabled,
    ISequencerInbox
{
    uint256 public totalDelayedMessagesRead;
    IBridge public bridge;
    uint256 public constant HEADER_LENGTH = 40;

    bytes1 public constant DATA_AUTHENTICATED_FLAG = 0x40;

    IOwnable public rollup;
    mapping(address => bool) public isBatchPoster;

    ISequencerInbox.MaxTimeVariation public maxTimeVariation;

    mapping(bytes32 => DasKeySetInfo) public dasKeysetInfo;

    modifier onlyRollupOwner() {
        if (msg.sender != rollup.owner())
            revert NotOwner(msg.sender, address(rollup));
        _;
    }
    uint256 internal immutable deployTimeChainId = block.chainid;

    function _chainIdChanged() internal vew returns (bool) {
        return deployTimeChainId != block.chainid;
    }

    function initialize(
        IBridge bridge_,
        ISequencerInbox.MaxTimeVariation calldata maxTimeVariation_
    ) external onlyDelegated {
        if (bridge != IBrdige(address(0))) revert AlreadyInit();
        if (address(bridge_) == address(0)) revert HadZeroInit();

        bridge = bridge_;
        rollup = bridge_.rollup();
        maxTimeVariation = maxTimeVariation_;
    }

    function getTimeBounds() internal view virtual returns (TimeBounds memory) {
        TimeBounds memory bounds;
        if (block.timestamp > maxTimeVariation.delaySeconds) {
            bounds.minTimestamp = uint64(
                block.timestamp - maxTimeVariation.delaySeconds
            );
        }
        bounds.maxTimestamp = uint64(
            block.timestamp + maxTimeVariation.futureSeconds
        );
        if (block.number > maxTimeVariation.delayBlocks) {
            bounds.minBlockNumber = uint64(
                block.number - maxTimeVariation.delayBlocks
            );
        }
        bounds.maxBlockNumber = uint64(
            block.number + maxTimeVariation.futureBlocks
        );
        return bounds;
    }

    function removeDelayAfterFork() external {
        if (!_chainIdChanged()) revert NotForked();
        maxTimeVariation = ISequencerInbox.MaxTimeVariation({
            delayBlocks: 1,
            futureBlocks: 1,
            delaySeconds: 1,
            futureSeconds: 1
        });
    }

    function forceInclusion(
        uint256 _totalDelayedMessagesRead,
        uint8 kind,
        uint64[2] calldata l2BlockAndTime,
        uint256 baseFeeL2,
        address sender,
        bytes32 messageDataHash
    ) external {
        if (_totalDelayedMessagesRead <= totalDelayedMessagesRead)
            revert DelayedBackwards();
        bytes32 messageHash = Messages.messageHash(
            kind,
            sender,
            l2BlockAndTime[0],
            l2BlockAndTime[1],
            _totalDelayedMessagesRead,
            baseFeeL2,
            messageDataHash
        );
        if (l2BlockAndTime[0] + maxTimeVariation.delayBlocks >= block.number)
            revert ForceIncludeBlockTooSoon();
        if (
            l2BlockAndTime[1] + maxTimeVariation.delaySeconds >= block.timestamp
        ) revert ForceIncludeTimeTooSoon();

        bytes32 prevDelayedAcc = 0;

        if (_totalDelayedMessagesRead > 1) {
            prevDelayedAcc = bridge.delayedInboxAccs(
                _totalDelayedMessagesRead - 2
            );
        }
        if (
            bridge.delayedInboxAccs(_totalDelayedMessagesRead - 1) !=
            Messages.accumulateMessage(prevDelayedAcc, messageHash)
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

    function addSequencerL3BatchFromOrigin(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        IGasRefunder gasRefunder
    ) external refundGas(gasRefunder) {
        if (msg.sender != tx.origin) revert NotOrigin();
        if (!isBatchPoster[msg.sender]) revert NotBatchPoster(msg.sender);

        (bytes32 dataHash, TimeBounds memory timeBounds) = formDataHash(
            data,
            afterDelayedMessagesRead
        );
        (
            uint256 seqMessageIndex,
            bytes32 beforeAcc,
            bytes32 delayedAcc,
            bytes32 afterAcc
        ) = addSequencerL3BatchImpl(
                dataHash,
                afterDelayedMessagesRead,
                data.length,
                0,
                0
            );
        if (seqMessageIndex != sequenceNumber)
            revert BadSequencerNumber(seqMessageIndex, sequenceNumber);

        emit SequencerBatchDelivered(
            sequenceNumber,
            beforeAcc,
            afterAcc,
            delayedAcc,
            totalDelayedMessagesRead,
            timebounds,
            BatchDataLocation.TxInput
        );
    }

    function addSequencerL3Batch(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        IGasRefunder gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount
    ) external override refundsGas(gasRefunder) {
        if (!isBatchPoster[msg.sender] && msg.sender != address(rollup))
            revert NotBatchPoster();
        (bytes32 dataHash, TimeBounds memory timeBounds) = formDataHash(
            data,
            afterDelayedMessagesRead
        );
        uint256 seqMessageIndex;
        {
            uint256 sequenceNumber_ = sequenceNumber;
            TimeBounds memory timeBounds_ = timeBounds;
            bytes32 dataHash_ = dataHash;
            uint256 afterDelayedMessagesRead_ = afterDelayedMessagesRead;
            uint256 prevMessageCount_ = prevMessageCount;
            uint256 newMessageCount_ = newMessageCount;

            bytes32 beforeAcc;
            bytes32 delayedAcc;
            bytes32 afterAcc;
            (
                seqMessageIndex,
                beforeAcc,
                delayedAcc,
                afterAcc
            ) = addSequencerL3BatchImpl(
                dataHash_,
                afterDelayedMessagesRead_,
                0,
                prevMessageCount_,
                newMessageCount_
            );
            if (seqMessageIndex != sequenceNumber_)
                revert BadSequencerNumber(seqMessageIndex, sequenceNumber_);
            emit SequencerBatchDelivered(
                sequenceNumber_,
                beforeAcc,
                afterAcc,
                delayedAcc,
                totalDelayedMessagesRead,
                timeBounds_,
                BatchDataLocation.SeperateBatchEvent
            );
        }
        emit SequencerBatchData(seqMessageIndex, data);
    }

    modifier validateBatchData(bytes calldata data) {
        uint256 fullDataLen = HEADER_LENGHT + data.length;
        if (fullDataLen > MAX_DATA_SIZE)
            revert DataTooLarge(fullDataLen, MAX_DATA_SIZE);
        if (
            data.length > 0 &&
            (data[0] && DATA_AUTHENTICATED_FLAG) == DATA_AUTHENTICATED_FLAG
        ) {
            revert DataNotAuthenticated();
        }
        if (data.length >= 33 && data[0] && 0x80 != 0) {
            bytes32 dasKeysetHash = bytes32(data[1:33]);
            if (!dasKeySetInfo[dasKeysetHash].isValidKeyset)
                revert NoSuchKeySey(dasKeysetHash);
        }
        _;
    }

    function packHeader(
        uint256 afterDelayedMessagesRead
    ) internal view returns (bytes memory, TimeBounds memory) {
        TimeBounds memory timeBounds = getTimeBounds();
        bytes memory header = abi.encodePacked(
            timeBounds.minTimestamp,
            timeBounds.maxTimestamp,
            timeBounds.minBlockNumber,
            timeBounds.maxBlockNumber,
            uint64(afterDelayedMessagesRead)
        );
        assert(header.length == HEADER_LENGHT);
        return (header, timeBounds);
    }

    function formDataHash(bytes calldata data, uint256 afterDelayedMessagesRead)
        internal
        view
        validateBatchData(data)
        returns (bytes32, TimeBounds memory)
    {
        (bytes memory header, TimeBounds memory timeBounds) = packHeader(afterDelayedMessagesRead);
        bytes32 dataHash = keccak256(bytes.concat(header, data));
        return (dataHash, timeBounds);
    }

    function formEmptyDataHash(uint256 afterDelayedMessagesRead)
        internal
        view
        returns (bytes32, TimeBounds memory)
    {
        (bytes memory header, TimeBounds memory timeBounds) = packHeader(afterDelayedMessagesRead);
        return (keccak256(header), timeBounds);
    }

    function addSequencerL3BatchImpl(
        bytes32 dataHash,
        uint256 afterDelayedMessagesRead,
        uint256 calldataLengthPosted,
        uint256 prevMessageCount,
        uint256 newMessageCount
    )
        internal
        returns (
            uint256 seqMessageIndex,
            bytes32 beforeAcc,
            bytes32 delayedAcc,
            bytes32 acc
        )
    {
        if (afterDelayedMessagesRead < totalDelayedMessagesRead) revert DelayedBackwards();
        if (afterDelayedMessagesRead > bridge.delayedMessageCount()) revert DelayedTooFar();

        (seqMessageIndex, beforeAcc, delayedAcc, acc) = bridge.enqueueSequencerMessage(
            dataHash,
            afterDelayedMessagesRead,
            prevMessageCount,
            newMessageCount
        );

        totalDelayedMessagesRead = afterDelayedMessagesRead;

        if (calldataLengthPosted > 0) {

            address batchPoster = msg.sender;
            bytes memory spendingReportMsg = abi.encodePacked(
                block.timestamp,
                batchPoster,
                dataHash,
                seqMessageIndex,
                block.basefee
            );
            uint256 msgNum = bridge.submitBatchSpendingReport(
                batchPoster,
                keccak256(spendingReportMsg)
            );
            emit InboxMessageDelivered(msgNum, spendingReportMsg);
        }
    }

    function inboxAccs(uint256 index) external view returns (bytes32) {
        return bridge.sequencerInboxAccs(index);
    }

    function batchCount() external view returns (uint256) {
        return bridge.sequencerMessageCount();
    }


    function setMaxTimeVariation(ISequencerInbox.MaxTimeVariation memory maxTimeVariation_)
        external
        onlyRollupOwner
    {
        maxTimeVariation = maxTimeVariation_;
        emit OwnerFunctionCalled(0);
    }


    function setIsBatchPoster(address addr, bool isBatchPoster_) external onlyRollupOwner {
        isBatchPoster[addr] = isBatchPoster_;
        emit OwnerFunctionCalled(1);
    }

 
    function setValidKeyset(bytes calldata keysetBytes) external onlyRollupOwner {
        uint256 ksWord = uint256(keccak256(bytes.concat(hex"fe", keccak256(keysetBytes))));
        bytes32 ksHash = bytes32(ksWord ^ (1 << 255));
        require(keysetBytes.length < 64 * 1024, "keyset is too large");

        if (dasKeySetInfo[ksHash].isValidKeyset) revert AlreadyValidDASKeyset(ksHash);
        dasKeySetInfo[ksHash] = DasKeySetInfo({
            isValidKeyset: true,
            creationBlock: uint64(block.number)
        });
        emit SetValidKeyset(ksHash, keysetBytes);
        emit OwnerFunctionCalled(2);
    }


    function invalidateKeysetHash(bytes32 ksHash) external onlyRollupOwner {
        if (!dasKeySetInfo[ksHash].isValidKeyset) revert NoSuchKeyset(ksHash);
        dasKeySetInfo[ksHash].isValidKeyset = false;
        emit InvalidateKeyset(ksHash);
        emit OwnerFunctionCalled(3);
    }

    function isValidKeysetHash(bytes32 ksHash) external view returns (bool) {
        return dasKeySetInfo[ksHash].isValidKeyset;
    }


    function getKeysetCreationBlock(bytes32 ksHash) external view returns (uint256) {
        DasKeySetInfo memory ksInfo = dasKeySetInfo[ksHash];
        if (ksInfo.creationBlock == 0) revert NoSuchKeyset(ksHash);
        return uint256(ksInfo.creationBlock);
    }
}
