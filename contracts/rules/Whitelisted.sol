pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../token/ISRC20.sol";

/**
 * @title Whitelisted transfer restriction example
 * @dev Example of simple transfer rule, having a list
 * of whitelisted addresses manged by owner, and checking
 * that from and to address in src20 transfer are whitelisted.
 */
contract Whitelisted is Ownable {
    mapping (address => bool) private _whitelisted;

    function whitelistAccount(address account) external onlyOwner {
        _whitelisted[account] = true;
    }

    function blacklistAccount(address account) external onlyOwner {
         _whitelisted[account] = false;
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _whitelisted[account];
    }
}
