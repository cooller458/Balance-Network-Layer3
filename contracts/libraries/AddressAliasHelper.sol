//SPDX-LICENSE-IDENTIFIER: MIT


pragma solidity ^0.8.19;


library AddressAliasHelper {
    uint160 internal constant OFFSET = uint160(0x1111000000000000000000000000000000001111);

    //// @notice utility function that cotnverts an address to L2  that submitted a tx to 
    /// the ınbox to the msg.sender viewed in the L3 contract
    /// l1Address the address in the L2 that triggered the tx to L3
    /// @return  l3Address L3 address as viewed in msg.sender
    function applyL2ToL3Alias(address l2Address) internal pure returns ( address l3Address) {
        unchecked {
            l3Address =  address(uint160(l2Address) + OFFSET);
        }
    }

    function undoL2ToL3Alias(address l3Address) internal pure returns ( address l2Address) {
        unchecked {
            l2Address =  address(uint160(l3Address) - OFFSET);
        }
    }
    

}