pragma solidity ^0.5.0;

/**
 * @dev Manager is responsible for minting and burning tokens in
 * response to SWM token staking changes.
 */
contract Managed {
    address private _manager;

    event ManagementTransferred(address indexed previousManager, address indexed newManager);

    /**
     * @dev The Managed constructor sets the original `manager` of the contract to the sender
     * account.
     */
    constructor () internal {
        _manager = msg.sender;
        emit ManagementTransferred(address(0), _manager);
    }

    /**
     * @return the address of the manager.
     */
    function manager() public view returns (address) {
        return _manager;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyManager() {
        require(isManager(), "Caller not manager");
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isManager() public view returns (bool) {
        return msg.sender == _manager;
    }

    /**
     * @dev Allows the current manager to relinquish control of the contract.
     * It will not be possible to call the functions with the `onlyManager`
     * modifier anymore.
     * @notice Renouncing management will leave the contract without an manager,
     * thereby removing any functionality that is only available to the manager.
     */
    function renounceManagement() external onlyManager returns (bool) {
        _manager = address(0);
        emit ManagementTransferred(_manager, address(0));
        return true;
    }

    /**
     * @dev Allows the current manager to transfer control of the contract to a newManager.
     * @param newManager The address to transfer management to.
     */
    function transferManagement(address newManager) external onlyManager returns (bool) {
        require(newManager != address(0));

        emit ManagementTransferred(_manager, newManager);
        _manager = newManager;
        return true;
    }
}
