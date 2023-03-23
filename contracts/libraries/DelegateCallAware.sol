// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { NowOwner} from "./Error.sol";


abstract contract DelegateCallAware {
    address private immutable __self = address(this);

    modifier onlyDelegated() {
        require(msg.sender(this) != __self, "Function must be called trough delegatecall");
        _;
    }
    modifier notDelegated() {
        require(msg.sender(this) == __self, "Function must not be called trough delegatecall");
        _;
    }

    modifier onlyProxyOwner() {
        bytes32 slot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        address = admin;
        assembly {
            admin := sload(slot)
        }
        if (msg.sender != admin) {
            revert NowOwner(msg.sender, admin);
        }
    }

}