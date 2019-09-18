pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/access/Roles.sol";
import "./Manager.sol";
import "../interfaces/ISRC20Registry.sol";


/**
 * @dev SRC20 registry contains addresses of every created 
 * SRC20 token. Registered factories can put addresses of
 * new tokens, public can query tokens.
 */
contract SRC20Registry is ISRC20Registry, Manager {
    using Roles for Roles.Role;

    event FactoryAdded(address account);
    event FactoryRemoved(address account);
    event SRC20Registered(address token, address tokenOwner);
    event SRC20Removed(address token);
    
    Roles.Role private _factories;


    /**
     * @dev constructor requiring SWM ERC20 contract address.
     */
    constructor(address swmERC20)
        Manager(swmERC20)
        public
    {
    }

    /**
     * @dev Adds new factory that can register token.
     * Emits FactoryAdded event.
     *
     * @param account The factory contract address.
     * @return True on success.
     */
    function addFactory(address account) external onlyOwner returns (bool) {
        require(account != address(0), "account is zero address");

        _factories.add(account);

        emit FactoryAdded(account);

        return true;
    }

    /**
     * @dev Removes factory that can register token.
     * Emits FactoryRemoved event.
     *
     * @param account The factory contract address.
     * @return True on success.
     */
    function removeFactory(address account) external onlyOwner returns (bool) {
        require(account != address(0), "account is zero address");

        _factories.remove(account);

        emit FactoryRemoved(account);

        return true;
    }

    /**
     * @dev Adds token to registry. Allowed only to factories.
     * Emits TokenRegistered event.
     *
     * @param token The token address.
     * @param tokenOwner Owner of the token.
     * @return True on success.
     */
    function put(address token, address roles, address tokenOwner) external returns (bool) {
        require(token != address(0), "token is zero address");
        require(tokenOwner != address(0), "tokenOwner is zero address");
        require(_factories.has(msg.sender), "factory not registered");

        _registry[token].owner = tokenOwner;
        _registry[token].roles = roles;

        emit SRC20Registered(token, tokenOwner);

        return true;
    }

    /**
     * @dev Removes token from registry.
     * Emits SRC20Removed event.
     *
     * @param token The token address.
     * @return True on success.
     */
    function remove(address token) external onlyOwner returns (bool) {
        require(token != address(0), "token is zero address");
        require(_registry[token].owner != address(0), "token not registered");

        delete _registry[token].owner;
        delete _registry[token].stake;
        delete _registry[token]._swm;
        delete _registry[token]._src;

        emit SRC20Removed(token);

        return true;
    }

    /**
     * @dev Checks if registry contains token.
     *
     * @param token The token address.
     * @return True if registry contains token.
     */
    function contains(address token) external view returns (bool) {
        return _registry[token].owner != address(0);
    }
}
