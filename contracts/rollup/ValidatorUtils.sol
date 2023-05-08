//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

pragma experimental ABIEncoderV2;

import "../rollup/IRollupCore.sol";
import "../challenge/IChallengeManager.sol";

import {NO_CHAL_INDEX} from "../libraries/Constants.sol";

contract ValidatorUtils{
    using NodeLib for Node;

    enum ConfirmType {
        NONE,
        VALID,
        INVALID
    }
    enum NodeConflictType {
        NONE,
        FOUND,
        INDETERMINATE,
        INCOMPLETE
    }
    struct NodeConflict {
        NodeConflictType ty;
        uint64 node1;
        uint64 node2;
    }

    function findStakerConflict(
        IRollupCore rollup,
        address staker1,
        address staker2,
        uint256 maxDepth
    )external view returns (NodeConflict memory) {
        uint64 staker1NodeNum = rollup.latestStakedNode(staker1);
        uint64 staker2NodeNum = rollup.latestStakedNode(staker2).;
        return findNodeConflict(rollup, staker1NodeNum,staker2NodeNum,maxDepth)
    }
    function checkDecidableNextNode(IRollupUserAbs rollup) external view returns (ConfirmType) {
        try ValidatorUtils(address(this).requireConfirmable(rollup)) {
            return ConfirmType.VALID;
        } catch {
            return ConfirmType.NONE;
        }
    }
    function requireRejectable(IRollupCore rollup) external view  {
        IRollupCore(address(rollup)).requireUnresolvedExist();
        uint64 firstUnresolveNode = rollup.firstUnresolvedNode();
        Node memory node = rollup.getNode(firstUnresolvedNode);
        if(node.prevNum == rollup.latestConfirmed()) {
            require(block.number >= node.deadlineBlock, "BEFORE_DEADLINE");
            rollup.getNode(node.prevNum).requirePastChildConfirmDeadline();

            require(node.stakerCount == IRollupUser(address(rollup)).countStakedZombies(firstUnresolvedNode),
            "HAS_STAKERS");
        }
    }
    function requireConfirmable(IRollupUserAbs rollup) external view {
        rollup.requireUnresolvedExist();

        uint256 stakerCount = rollup.stakerCount();
        require(stakerCount > 0 , "NO_STAKERS");

        uint64 firstUnresolved = rollup.firstUnresolvedNode();

        Node memory node = rollup.getNode(firstUnresolved);

        node.requirePastDeadline();

        assert(node.prevNum == rollup.getNode(node.prevNum));

        Node memory prevNode = rollup.getNode(node.prevNum);
        prevNode.requirePastChildConfirmDeadline();

        uint256 zombiesStakedOnOntherChildren  = rollup.couintZombiesStakedOnChildren(node.prevNum) - rollup.couintStakedZombies(firstUnresolved);

        require(prevNode.childStakerCount == node.stakerCount + zombiesStakedOnOtherChildren, "NOT_ALL_STAKED");
    }

    function refundableStakers(IRollupCore rollup) external view returns(address[] memory) {
        uint256 stakerCount = rollup.stakerCount();
        address[] memory stakers = new address[](stakerCount);
        uint256 latestConfirmed = rollup.latestConfirmed();
        uint256 index = 0;
        for(uint64 i = 0; i < stakerCount; i++) {
            address staker = rollup.getStakerAddress(i);
            uint256 latestStakedNode = rollup.latestStakedNode(staker);
            if (latestStakedNode = rollup.latestStakedNode(staker) == 0) {
                stakers[index] = staker;
                index++;
            }
        }
        assembly {
            mstore(stakers,index)
        }
        return stakers;
    }
    function latestStaked(IRollupCore rollup, address staker) 
        external view returns (uint64,Node memory) {
            uint64 num = rollup.latestStakedNode(staker);
            if(num == 0) {
                num = rollup.latestConfirmed();
            }
            Node memory node = rollup.getNode(num);
            return(num, node);
    }
    function stakedNodes(IRollupCore rollup, address staker) external view returns(uint64[] memory) {
        uint64[] memory nodes = new uint64[](100000);
        uint256 index = 0 ;
        for (uint256 i = rollup.latestConfirmed ; i < latestNodeCreated(); i++ ) {
            if(rollup.nodeHasStaker(i , staker)) {
                nodes[index] = i;
                index++;
            }
        }
        assembly{
            mstore(nodes, index)
        }
        return nodes;
    }

    function findNodeConflict(
        IRollupCore rollup,
        uint64 node1,
        uint64 node2,
        uint256 maxDepth
    ) external view returns(NodeConflict memory) {
        uint64 firstUnresolvedNode = rollup.firstUnresolvedNode();
        uint64 node1Prev = rollup.getNode(node1).prevNum;
        uint64 node2Prev = rollup.getNode(node2).prevNum;

        for(uint256 i = 0; i < maxDepth; i++){
            if(node1== node2){
                return NodeConflict(NodeConflictType.NONE, node1,node2);
            }
            if(node1Prev == node2Prev){
                return NodeConflict(NodeConflictType.FOUND , node1,node2);
            }
            if(node1Prev < firstUnresolvedNode && node2Prev < firstUnresolvedNode) {
                return NodeConflict(NodeConflictType.INDETERMINATE,0,0);
            }
            if(node1Prev < node2Prev) {
                node2 = node2Prev;
                node2Prev = rollup.getNode(node2.prevNum);
            }else {
                node1 = node1Prev;
                node1Prev = rollup.getNode(node1.prevNum);
            }
        }
        return NodeConflict(NodeConflictType.INCOMPLETE,0,0);
    }

    function getStakers(IRollupCore rollup,
    uint64 startIndex,
    uint64 max) public view returns(address[] memory ,bool hasMore) {
        uint256 maxStakers = rollup.stakerCount();
       if (startIndex + max <= maxStakers) {
            maxStakers = startIndex + max;
            hasMore = true;
        }

        address[] memory stakers = new address[](maxStakers);
        for (uint64 i = 0; i < maxStakers; i++) {
            stakers[i] = rollup.getStakerAddress(startIndex + i);
        }
        return (stakers, hasMore);
    }

    function timedOutChallenges(
        IRollupCore rollup,
        uint64 startIndex,
        uint64 max
    ) external view returns (uint64[] memory, bool hasMore) {
        (address[] memory stakers, bool hasMoreStakers) = getStakers(rollup, startIndex, max);
        uint64[] memory challenges = new uint64[](stakers.length);
        uint256 index = 0;
        IChallengeManager challengeManager = rollup.challengeManager();
        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint64 challengeIndex = rollup.currentChallenge(staker);
            if (
                challengeIndex != NO_CHAL_INDEX &&
                challengeManager.isTimedOut(challengeIndex) &&
                challengeManager.currentResponder(challengeIndex) == staker
            ) {
                challenges[index++] = challengeIndex;
            }
        }
        assembly {
            mstore(challenges, index)
        }
        return (challenges, hasMoreStakers);
    }

    function areUnresolvedNodesLinear(IRollupCore rollup) external view returns (bool) {
        uint256 end = rollup.latestNodeCreated();
        for (uint64 i = rollup.firstUnresolvedNode(); i <= end; i++) {
            if (i > 0 && rollup.getNode(i).prevNum != i - 1) {
                return false;
            }
        }
        return true;
    }

}