pragma solidity ^0.5.0;

/**
 * @dev Interface for SRC20 Registry contract
 */
contract ISRC20Registry {
    event FactoryAdded(address account);
    event FactoryRemoved(address account);
    event SRC20Registered(address token, address tokenOwner);
    event SRC20Removed(address token);

    function put(address token, address roles, address tokenOwner) external returns (bool);
    function remove(address token) external returns (bool);
    function contains(address token) external view returns (bool);

    function addFactory(address account) external returns (bool);
    function removeFactory(address account) external returns (bool);
}