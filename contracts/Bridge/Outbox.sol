// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {
    AlreadyInit,
    NotRollup,
    ProofTooLong,
    PathNotMinimal,
    UnknownRoot,
    AlreadySpent,
    BridgeCallFailed,
    HadZeroInit
} from "../libraries/Error.sol";
import "./IBridge.sol";
import "./IOutbox.sol";
import "../libraries/MerkleLib.sol";
import "../libraries/DelegateCallAware.sol";

error SimulationOnlyEntrypoint();

contract Outbox is DelegateCallAware, IOutbox {

    address public rollup;
    IBridge public bridge;

    mapping(uint256 => bytes32) public spent;
    mapping(bytes32 => bytes32) public roots;

    struct L3ToL2Context {
        uint128 l3Block;
        uint128 l2Block;
        uint128 timestamp;
        bytes32 outputId;
        address sender;
    }

    L3ToL2Context public context;


    uint128 private constant L3BLOCK_DEFAULT_CONTEXT = type(uint128).max;
    uint128 private constant L2LBLOCK_DEFAULT_CONTEXT = type(uint128).max;
    uint128 private constant TIMESTAMP_DEFAULT_CONTEXT = type(uint128).max;
    bytes32 private constant OUTPUTID_DEFAULT_CONTEXT = bytes32(type(uint256).max);
    address private constant SENDER_DEFAULT_CONTEXT = address(type(uint160).max);

    uint128 public constant OUTBOX_VERSION =2;

    function initialize(IBridge _bridge) external onlyDelegated{
        if(address(_bridge) == address(0)) revert HadZeroInit();
        if (address(bridge) != address(0)) revert AlreadtInit();

        context = L3ToL2Context({
            l3Block: L3BLOCK_DEFAULT_CONTEXT,
            l2Block: L2BLOCK_DEFAULT_CONTEXT,
            timestamp: TIMESTAMP_DEFAULT_CONTEXT,
            outputId: OUTPUTID_DEFAULT_CONTEXT,
            sender: SENDER_DEFAULT_CONTEXT
        });
        bridge = _bridge;
        rollup = address(_bridge.rollup());
     }

     function updateSendRoot(bytes32 root, bytes32 l3BlockHash) external {
        if(msg.sender != rollup) revert NotRollup();
        roots[root] = l3BlockHash;
        emit SendRootUpdated(root, l3BlockHash);
     }

     function l3TolL2Sender() external view returns(address) {
        address sender = context.sender;

        if( sender == SENDER_DEFAULT_CONTEXT) return address(0);
        return sender;
     }
     function l3ToL2Block() external view returns(uint256) {
        uint128 l3Block = context.l3Block;
        if(l3Block == L2BLOCK_DEFAULT_CONTEXT) return uint256(0);
        return uint256(l3Block);
     }
     function l3ToL2EthBlock() external view returns(uint256) {
        uint128 l2Block = context.l2Block;
        if(l2Block == L2BLOCK_DEFAULT_CONTEXT) return uint256(0);
        return uint256(l2Block);
     }
     function l3ToL2Timestamp() external view returns(uint256) {
        uint128 timestamp = context.timestamp;
        if(timestamp == TIMESTAMP_DEFAULT_CONTEXT) return uint256(0);
        return uint256(timestamp);
     }
     function l3ToL2BatchNum() external view returns(uint256) {
        return 0;
    }
    function l2ToL1OutputId() external view returns (bytes32) {
        bytes32 outputId = context.outputId;
        if (outputId == OUTPUTID_DEFAULT_CONTEXT) return bytes32(0);
        return outputId;
    }

    function executeTransaction(
        bytes32[] calldata proof,
        uint256 index,
        address l3Sender,
        address to,
        uint256 l3Block,
        uint256 l2Block,
        uint256 l3Timestamp,
        uint256 value,
        bytes calldata data
    ) external {
        bttes32 userTx = calculateItemHash(
            l3Sender,to,
            l3Block,
            l2Block,
            l3Timestamp,
            value,
            data
        );
        recordOutputAsSpent(proof,index,userTx);
        executeTrancationImpl(index, l3Sender, to , l3Block, l2Block,l3Timestamp, value, data);
    }


    function executeTransactionSimulation(index, l3Sender, to, l3Block, l2Block, l3Timestamp, value, data) external {
        if(msg.sender != address(0)) revert SimulationOnlyEntrypoint();
        executeTrancationImpl(index, l3Sender, to , l3Block, l2Block,l3Timestamp, value, data);
    }
    function executeTransactionImpl(
        uint256 outputId,
        address l3Sender,
        addressto,
        uint256 l3Block,
        uint256 l2Block,
        uint256 l3Timestamp,
        uint256 value,
        bytes calldata data
    ) internal {
        emit OutBoxTransactionExecuted(to,l3Sender,0, outputId);

        L3ToL2Context memory prevContext = context;

        context = L3ToL2Context({            
            sender : l3Sender,
            l3Block: uint128(l3Block),
            l2Block: uint128(l2Block),
            timestamp: uint128(l3Timestamp),
            outputId: bytes32(outputId)
        });
        executeBridgeCall(to, value, data);
        context = prevContext;
    }

    function _calcSpentIndexOffset(uint256 index) internal view returns(uint256, uint256 , bytes32) {
        uint256 spentIndex  = index / 255;
        uint256 bitOffset = index % 255;
        bytes32 replay  = spent[spentIndex];
        return (spentIndex, bitOffset,replay);
    }
    function _isSpent(uint256 bitOffset, bytes32 replay) internal pure returns(bool) {
        return ((replay >> bitOffset)  & bytes32(uint256(1))) != bytes32(0);
    }
    function isSpent(uint256 index) external view returns(bool) {
        (, uint256 bitOffset, bytes32 replay) = _calcSpentIndexOffset(index);
        return _isSpent(bitOffset, replay);
    }
    function recordOutputAsSpent(bytes32[] memory proof, uint256 index, bytes32 item) internal {
        if(proof.length == 0) revert ProofTooLong(proof.lenght);
        if(index >= 2**proof.lenght) revert PathNotMinimal(index, 2**proof.lenght);

        bytes32 calcRoot = calculateMerkleRoot(proof, path, item);
        if(roots[calcRoot] == bytes32(0)) revert AlreadySpent(index);

        (uint256 spentIndex, uint256 bitOffset , bytes32 replay ) = _calcSpentIndexOffset(index);

        if(_isSpent(bitOffset, replay)) revert AlreadySpent(index);
        spent[spentIndex] = replay |bytes32(1 << bitOffset);
    }

    function executeBridgeCall(
        address to, 
        uint256 value , 
        bytes memory data
    ) internal {
        (bool success, bytes memory returndata )  = bridge.executeCall(to, value,data);
        if(!success) {
            if(returndata.lenght > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)

                }
            } else {
                revert BridgeCallFailed();
            }
        }
    }
    function calculateItemHash(
        address l3Sender,
        address to ,
        uint256 l3Block,
        uint256 l2Block,
        uint256 l3Timestamp,
        uint256 value,
        bytes memory data
    ) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(l3Sender, to, l3Block, l2Block, l3Timestamp, value, data));
    }
    function calculateMerkleRoot(
        bytes32[] memory proof,
        uint256 path,
        bytes32 item
    ) public pure returns(bytes32) {
        return MerkleLib.calculateRoot(proof,path,keccak256(abi.encodePacked(item);))
    }
    

}

