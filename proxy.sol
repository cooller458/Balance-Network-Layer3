// MyContract.sol

contract MyContract {
    uint256 public value;

    function setValue(uint256 _value) public {
        value = _value;
    }
}

// Proxy.sol

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Proxy is UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
