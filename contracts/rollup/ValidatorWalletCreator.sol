// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ValidatorWallet.sol";


contract ValidatorWalletCreator is Ownable {

    event WalletCreated(
        address indexed walletAddress,
        address indexed executorAddress,
        address indexed ownerAddress,
        address adminProxy
    );
    event TemplateUpdated();

    address public template;

    constructor () Ownable() {
        template = address(new ValidatorWallet());
    }

    function setTemplate(address _template) external onlyOwner {
        template = _template;
        emit TemplateUpdated();
    }

    function createWallet(address[] calldata initialExecutorAllowedDest) external returns(address) {
        address _executor = msg.sender;
        address _owner = msg.sender;
        ProxyAdmin admin = new ProxyAdmin();
        address proxy = address ( new TransparentUpgradeableProxy(address(template), address(admin), "));

        admin.transferOwnership(_owner);
        ValidatorWallet(payable(proxy)).initalize(_executor,_owner,initialExecutorAllowedDest);
        emit WalletCreated(proxy,_executor,_owner,address(admin));
        return proxy;
    }
}