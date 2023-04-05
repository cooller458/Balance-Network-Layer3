
pragma solidity ^0.8.4;


error AlreadyInit();

error HadZeroInit();

error NotOwner(address sender, address owner);

error NotRollup(address sender, address rollup);

error NotOrigin();

error DataTooLarge(uint256 dataLength, uint256 maxDataLength);

error NotContract(address addr);

error MerkleProofTooLong(uint256 actualLength, uint256 maxProofLength);

error NotRollupOrOwner(address sender, address rollup, address owner);

error NotDelayedInbox(address sender);

error NotSequencerInbox(address sender);

error NotOutbox(address sender);

error InvalidOutboxSet(address outbox);

error AlreadyPaused();

error AlreadyUnpaused();

error Paused();

error InsufficientValue(uint256 expected, uint256 actual);

error InsufficientSubmissionCost(uint256 expected, uint256 actual);

error NotAllowedOrigin(address origin);

error RetryableData(
    address from,
    address to,
    uint256 l2CallValue,
    uint256 deposit,
    uint256 maxSubmissionCost,
    address excessFeeRefundAddress,
    address callValueRefundAddress,
    uint256 gasLimit,
    uint256 maxFeePerGas,
    bytes data
);

error L2Forked();

error NotForked();

error GasLimitTooLarge();

error ProofTooLong(uint256 proofLength);

error PathNotMinimal(uint256 index, uint256 maxIndex);

error UnknownRoot(bytes32 root);

error AlreadySpent(uint256 index);

error BridgeCallFailed();

error DelayedBackwards();

error DelayedTooFar();

error ForceIncludeBlockTooSoon();

error ForceIncludeTimeTooSoon();

error IncorrectMessagePreimage();

error NotBatchPoster();

error BadSequencerNumber(uint256 stored, uint256 received);

error BadSequencerMessageNumber(uint256 stored, uint256 received);

error DataNotAuthenticated();

error AlreadyValidDASKeyset(bytes32);

error NoSuchKeyset(bytes32);