// SPDX-License-Identifier: MIT

pragma solidity >=0.6.9 <0.9.0;
pragma experimental ABIEncoderV2;

import "../libraries/IGasRefunder.sol";
import "./IDelayedMessageProvider.sol";
import "./IBridge.sol";

interface ISequencerInbox is IDelayedMessageProvider {
    struct MaxTimeVariation {
        uint256 delayBlocks;
        uint256 futureBlocks;
        uint256 delaySeconds;
        uint256 futureSeconds;
    }
    struct TimeBounds {
        uint64 minTimestamp;
        uint64 maxTimestamp;
        uint64 minBlockNumber;
        uint64 maxBlockNumaber;
    }

    enum BatchDataLocation{
        TxInput,
        SeperateBatchEvent,
        NoData
    }

    event SequencerBatchDelivered(
        uint256 indexed batchSequenceNumber,
        bytes32 indexed beforeAcc,
        bytes32 indexed afterAcc,
        bytes32 delayedAcc,
        uint256 afterDelayedMessagesRead,
        TimeBounds timebounds,
        BatchDataLocation dataLocation
    );

    event OwnerFunctionCalled(uint256 indexed id);

    event SequencerBatchData(uint256 indexed batchSequenceNumber, bytes data);

    event SetValidKeysey(bytes32 indexed keysetHash, bytes keysetBytes);

    event InvalidateKeysey(bytes32 indexed keysetHash);

    function totalDelayedMessagesRead() external view returns(uint256);

    function bridge() external view returns(IBridge);

    function HEADER_LENGHT() external view returns(uint256);

    function DATA_AUTHENTICATED_FLAG() external view returns(bytes1);

    function rollup() external view returns(IOwnable);

    function isBatchPoster(address) external view returns(bool);

    struct DasKeySetInfo {
        bool isValidKeyset;
        uint64 creationBlock;
    }

    function removeDelayAfterFork() external;

    function forceInclusion(
        uint256 _totalDelayedMessagesRead,
        uint8 kind,
        uint64[2] calldata l2BlockAndTime,
        uint256 baseFeeL2,
        address sender, bytes32 messageDataHash
    ) external;
    function inboxAccs(uint256 index) external view returns(bytes32);

    function batchCount() external view returns(uint256);

    function isValidKeysetHash(bytes32 ksHash) external view returns(bool);

    function getKeysetCreationBlock(bytes32 ksHash) external view returns(uint256);

    function addSequnecerL3BatchFromOrigin(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessageRead,
        IGasRefunder gasRefunder
    ) external;

    function addSequencerL3Batch(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessageRead,
        IGasRefunder gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount
    ) external;

    function setMaxTimeVariation(MaxTimeVariation memory maxTimeVariation) external;

    function setIsBatchPoster(address addr, bool isBatchPoster_) external;

    function setValidKeyset(bytes calldata keysetBytes) external;

    function invalidateKeyseyHash(bytes32 keysetHash) external;

    function initialize(IBridge bridge_, MaxTimeVariation calldata maxTimeVariation) external;

}   