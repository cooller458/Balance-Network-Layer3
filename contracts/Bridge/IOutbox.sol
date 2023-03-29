// SPDX-License-Identifier: MIT

pragma solidity >=0.6.9 <0.9.0;

import "./IBridge.sol";



interface IOutbox {
    event SendRootUpdated(bytes32 indexed outputRoot, bytes32 indexed l3Blockhash);

    event OutBoxTransactionExecuted(
        address indexed to, 
        address indexed l3Sender,
        uint256 indexed zero,
        uint256 transactionIndex
    );

    function rollup() external view returns(address);

    function bridge() external view returns(IBridge);

    function spent(uint256) external view returns(bytes32);

    function roots(bytes32) external view returns(bytes32);

    function OUTBOX_VERSION() external view returns(uint128);

    function updateSendRoot(bytes32 sendRoot, bytes32 l3Blockhash) external;

    function l3ToL2Sender() external view returns(address);

    function l3ToL2Block() external view returns(uint256);

    function l3ToL2EthBlock() external  view returns(uint256);

    function l3ToL2Timestamp() external view returns(uint256);

    function l3ToL2OutputId() external view returns(bytes32);

    function executeTransaction(
        bytes32[] calldata proof,
        uint256 index,
        address l3Sender,
        address to,
        uint256 l3BLock,
        uint256 l2Block,
        uint256 l3Timestamp,
        uint256 value,
        bytes calldata data
    ) external;

    function executeTransactionSimulation(
        uint256 index,
        address l3Sender,
        address to,
        uint256 l3Block,
        uint256 l2Block,
        uint256 l3Timestamp,
        uint256 value,
        bytes calldata data
    ) external;

    function isSpent(uint256 index) external view returns(bool);

    function calculateItemHash(
        address l3Sender,
        address to,
        uint256 l3Block,
        uint256 l2Block,
        uint256 l3Timestamp,
        uint256 value,
        bytes calldata data

    ) external pure returns(bytes32);

    function calculateMerkleRoot(
        bytes32[] memory proof,
        uint256 path,
        bytes32 item
    ) external pure returns(bytes32);
}