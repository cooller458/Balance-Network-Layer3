// SPDX-LICENSE-IDENTIFIER: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "@openzeppelin/contracs/utils/address.sol";
import "@openzeppelin/contract/utils/StorageSlot.sol";




abstract contract  DoubleLogicERC1967Upgrade is ERC1967Upgrade {


    bytes32 internal constant _IMPLEMENTATION_SECONDARY_SLOT = 
    0x2b1dbce74324248c222f0ec2d5ed7bd323cfc425b336f0253c5ccfda7265546d;


    bytes32 internal constant _ROLLBACK_SECONDARY_SLOT = 
    0x49bd798cd84788856140a4cd5030756b4d08a9e4d55db725ec195f232d262a89;

    event UpgradedSecondary(address indexed implementation);

    function _getSecondaryImplementation() internal pure returns(address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SECONDARY_SLOT).value;
    }

    function _setSecondaryImplementation(address newImplementation) private {
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SECONDARY_SLOT).value = newImplementation;
    }

    function _upgradeSecondaryTo(address newImplementation) internal {
        _setSecondaryImplementation(newImplementation);
        emit UpgradedSecondary(newImplementation);
    }

    function _upgradeSecondaryToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeSecondaryTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }
    function _upgradeSecondaryToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {

        if (StorageSlot.getBooleanSlot(_ROLLBACK_SECONDARY_SLOT).value) {
            _setSecondaryImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(
                    slot == _IMPLEMENTATION_SECONDARY_SLOT,
                    "ERC1967Upgrade: unsupported secondary proxiableUUID"
                );
            } catch {
                revert("ERC1967Upgrade: new secondary implementation is not UUPS");
            }
            _upgradeSecondaryToAndCall(newImplementation, data, forceCall);
        }
    }
}

contract AdminFallbackProxy is Proxy, DoubleLogicERC1967Upgrade {

    constructor(
        address adminLogic,
        bytes memory adminData,
        address userLogic,
        bytes memory userData,
        address adminAddr
    ) payable {
        assert(_ADMIN_SLOT == bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
        assert(
            _IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );
        assert(
            _IMPLEMENTATION_SECONDARY_SLOT ==
                bytes32(uint256(keccak256("eip1967.proxy.implementation.secondary")) - 1)
        );
        _changeAdmin(adminAddr);
        _upgradeToAndCall(adminLogic, adminData, false);
        _upgradeSecondaryToAndCall(userLogic, userData, false);
    }

    function _implementation() internal view override returns (address) {
        require(msg.data.length >= 4, "NO_FUNC_SIG");
        address target = _getAdmin() != msg.sender
            ? DoubleLogicERC1967Upgrade._getSecondaryImplementation()
            : ERC1967Upgrade._getImplementation();
        require(Address.isContract(target), "TARGET_NOT_CONTRACT");
        return target;
    }
    function _beforeFallback() internal override {
        super._beforeFallback();
    }
}