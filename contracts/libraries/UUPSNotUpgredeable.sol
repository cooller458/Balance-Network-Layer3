// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";
import {DoubleLogicERC1967Upgrade} from "./AdminFallbackProxy.sol";

abstract contract UUPSNotUpgradeable is IERC1822Proxiable, DoubleLogicERC1967Upgrade {

    address private immutable __self = address(this);

    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(
            _getSecondaryImplementation() == __self,
            "Function must be called through active proxy"
        );
        _;
    }

    modifier notDelegated() {
        require(
            address(this) == __self,
            "UUPSNotUpgradeable: must not be called through delegatecall"
        );
        _;
    }


    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SECONDARY_SLOT;
    }
}