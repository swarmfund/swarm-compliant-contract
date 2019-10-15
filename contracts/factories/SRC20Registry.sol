pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/access/Roles.sol";
import "./Manager.sol";
import "../interfaces/ISRC20Registry.sol";


/**
 * @dev SRC20 registry contains the address of every created 
 * SRC20 token. Registered factories can add addresses of
 * new tokens, public can query tokens.
 */
contract SRC20Registry is ISRC20Registry, Manager {
    using Roles for Roles.Role;

    Roles.Role private _factories;
    mapping (address => bool) _authorizedMinters;

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
     * @dev Adds token to registry. Only factories can add.
     * Emits SRC20Registered event.
     *
     * @param token The token address.
     * @param roles roles SRC20Roles contract address.
     * @param tokenOwner Owner of the token.
     * @return True on success.
     */
    function put(address token, address roles, address tokenOwner, address minter) external returns (bool) {
        require(token != address(0), "token is zero address");
        require(roles != address(0), "roles is zero address");
        require(tokenOwner != address(0), "tokenOwner is zero address");
        require(_factories.has(msg.sender), "factory not registered");
        require(_authorizedMinters[minter] == true, 'minter not authorized');

        _registry[token].owner = tokenOwner;
        _registry[token].roles = roles;
        _registry[token].minter = minter;

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

        delete _registry[token];

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

    /**
     *  This proxy function adds a contract to the list of authorized minters
     *
     *  @param minter The address of the minter contract to add to the list of authorized minters
     *  @return true on success
     */
    function addMinter(address minter) external onlyOwner returns (bool) {
        require(minter != address(0), "minter is zero address");

        _authorizedMinters[minter] = true;

        emit MinterAdded(minter);

        return true;
    }

    /**
     *  With this function you can check if address is allowed minter for SRC20.
     *
     *  @param src20 Address of SRC20 token we want to check minters for.
     *  @param minter The address of the minter contract to check.
     *  @return true if address is minter.
     */
    function isMinter(address src20, address minter) external view returns (bool) {
        return _registry[src20].minter == minter;
    }

    /**
     *  This proxy function removes a contract from the list of authorized minters
     *
     *  @param minter The address of the minter contract to remove from the list of authorized minters
     *  @return true on success
     */
    function removeMinter(address minter) external onlyOwner returns (bool) {
        require(minter != address(0), "minter is zero address");

        _authorizedMinters[minter] = false;

        emit MinterRemoved(minter);

        return true;
    }
}
