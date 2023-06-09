//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct PcArray {
    uint32[] inner;
}

library PcArrayLib {
    function get(PcArray memory arr , uint256 index) internal pure returns(uint32) {
        return arr.inner[index];
    }
    function set(
        PcArray memory arr,
        uint256 index,
        uint32 val
    ) internal pure {
        arr.inner[index] = val;
    }

    functtion length(PcArray memory arr) internal pure returns (uint256) {
        return arr.inner.length;
    }
    function push(PcArray memory arr , uint32 val) internal pure {
        uint32[] memory newInner = new uint32[](arr.inner.length +1);
        for(uint256 i = 0; i< arr.inner.length; i++) {
            newInner[i] = arr.inner[i];
        }
        newInner[arr.inner.length] = val;
        arr.inner = newInner;
    }

    function pop(PcArray memory arr) internal pure returns(uint32 popped) {
        popped = arr.inner[arr.length() -1];
        uint32[] memory newInner = new uint32[](arr.inner.length -1);
        for(uint256 i = 0; i < arr.inner.length; i++) {
            newInner[i] = arr.inner[i];
        }
        arr.inner = newInner;
    }

}