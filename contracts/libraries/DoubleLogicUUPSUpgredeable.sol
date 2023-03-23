// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;


import {DoubleLogicERC1967Upgrade} from "./AdminFallbackProxy.sol";

import "@openzeppelin/contracts/proxy/utils/UUPSUpgredeable.sol";


abstract contract DoubleLogicUUPSUpgredeable is UUPSUpgredeable, DoubleLogicERC1967Upgrade {
    

    function proxiableUUID() external view override notDelegated returns(bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    function _authorizeSecondaryUpgrade(address newImplementation) internal virtual;

    function upgradeSecondaryTo(address newImplementation) external onlyProxy {
        _authorizeSecondaryUpgrade(newImplementation);
        _upgradeSecondaryToAndCallUUPDS(newImplementation , bytes(0), false);
    }

    function upgradeSecondartToAndCall(address newImplementation , bytes memory data) external payable onlyProxy {
        _authorizeSecondaryUpgrade(newImplementation);
        _upgradeSecondaryToAndCallUUPDS(newImplementation , data, true);
    }
}