// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../challenge/IChallengeManager.sol";
import "../libraries/DelegateCallAware.sol";
import "../libraries/IGasRefunder.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

error BadArrayLength(uint256 expected, uint256 actual);

error NotExecuteOrOwner(address actual);

error OnlyOwnerDestination(
    address expected,
    address actual,
    address destination
);

error WithdrawEthFail(address destination);

contract ValitadorWallet is OwnableUpgredeable , DelegateCallAware ,GasRefundEnabled {

    using Address for address ;

    mapping(address => bool) public executors;

    mapping(address => bool) public allowedExecutorDestination;

    modifier onlyExecutorOrOwner() {
        if(!executors[_msg.sender()] && owner() != _msgSender()) {
            revert NotExecuteOrOwner(_msgSender());
        }
    }

    event ExecutorUpdated(address indexed executor, bool isExecutor);

    function setExecutor(adresss[] calldata newExecutors, bool[] calldata isExecutor) external onlyOwner {
        if(newExecutors.length != isExecutor.length) {
            revert BadArrayLength(newExecutors.length, isExecutor.length);
        }
        unchecked {
            for(uint256 i = 0 ; i < newExecutors.length ; i++) {
                executors[newExecutors[i]] = isExecutor[i];
                emit ExecutorUpdated(newExecutors[i], isExecutor[i]);
            }
        }
    }

    function initialize(
        address _executor,
        address _owner,
        address[] calldata initialExecutorAllowedDest
    ) external initialized onlyDelegated {
        __Ownable_init();
        transferOwnership(_owner);

        executors[_executor] = true;
        emit ExecutorUpdated(_executor, true);

        unchecked {
            for(uint64 i = 0 ; i < initialExecutorAllowedDest.length ; i++) {
                allowedExecutorDestination[initialExecutorAllowedDest[i]] = true;
                emit AllowedExecutorDestinationUpdated(initialExecutorAllowedDest[i], true);
            }
        }
    }

    event AllowedExecutorDestinationUpdated(address indexed destination , bool isSet);

    function setAllowedExecutoDestination(address[] calldata destionations, bool[] calldata isSet) external onlyOwner{
        if(destionations.length != isSet.length) {
            revert BadArrayLength(destionations.length, isSet.length);
        }
        unchecked {
            for(uint256 i = 0 ; i < destinations.length; i++){
                allowedExecutorDestinations[destinations[i]] = isSet[i];
                emit AllowedExecutorDestinationUpdated(destinations[i], isSet[i]);
            }
        }
    }

    function validateExecuteTransaction(address destination) public view {
        if(!allowedExecutorDestinations[destination] && owner() != _msgSender())
        revert OnlyOwnerDestination(owner(), _msgSender(), destination);
    }

    function executeTransactions(bttes[] calldata data ,address[] calldata destination,
    uint256[] calldata amount) external payable {
        executeTransactionsWithGasRefunder(IGasRefunder(address(0)), data ,destination,amount);
    }

    function executeTransactionWithGasRefunder(
        IGasRefunder gasRefunder,
        bytes[] calldata data,
        address[] calldata destination,
        uint256[] calldata amount
    ) public payable onlyExecutorOrOwner refundsGas(gasRefunder) {
        if(data.length > 0) require(destination.isContract(), "NO_CODE_AT_ADDR");
        validateExecuteTransaction(destination);

        (bool success,) = destination.call{value: amount}(data);
        if(!success) {
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize()
                revert(ptr,size)
            }
        }
        
    }

    function timeoutChallenges(IChallengeManager manager, uint64[] calldata challenges) external {
        timeoutChallengesWithGasRefunder(IGasRefunder(address(0)), manager , challenges);
    }
        function timeoutChallengesWithGasRefunder(
        IGasRefunder gasRefunder,
        IChallengeManager manager,
        uint64[] calldata challenges
    ) public onlyExecutorOrOwner refundsGas(gasRefunder) {
        uint256 challengesCount = challenges.length;
        for (uint256 i = 0; i < challengesCount; i++) {
            try manager.timeout(challenges[i]) {} catch (bytes memory error) {
                if (error.length == 0) {

                    require(false, "GAS");
                }
            }
        }
    }
    receive() external payable {}

    function withdrawEth(uint256 amount, address destination) external onlyOwner {
        (bool success, ) = destination.call{value: amount}("");
        if (!success) revert WithdrawEthFail(destination);
    }

}
