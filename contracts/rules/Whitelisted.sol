pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/ownership/Ownable.sol";
import "../interfaces/ISRC20.sol";

/**
 * @title Whitelisted transfer restriction example
 * @dev Example of simple transfer rule, having a list
 * of whitelisted addresses manged by owner, and checking
 * that from and to address in src20 transfer are whitelisted.
 */
contract Whitelisted is Ownable {
    mapping (address => bool) public _whitelisted;

    function whitelistAccount(address account) external onlyOwner {
        _whitelisted[account] = true;
    }

    function bulkWhitelistAccount(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length ; i++) {
            address account = accounts[i];
            _whitelisted[account] = true;
        }
    }

    function unWhitelistAccount(address account) external onlyOwner {
         delete _whitelisted[account];
    }

    function bulkUnWhitelistAccount(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length ; i++) {
            address account = accounts[i];
            delete _whitelisted[account];
        }
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _whitelisted[account];
    }
}
