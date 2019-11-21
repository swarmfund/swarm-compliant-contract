pragma solidity ^0.5.0;

import "../interfaces/IContributorRestrictions.sol";
import "./ContributorWhitelist.sol";
import "../fundraising/SwarmPoweredFundraise.sol";
import "../roles/DelegateRole.sol";

contract ContributorRestrictions is IContributorRestrictions, ContributorWhitelist, DelegateRole {

    address payable _fundraising;

    modifier onlyAuthorised() {
        require(msg.sender == owner() ||
                msg.sender == _fundraising ||
                _hasDelegate(msg.sender),
                "ContributorRestrictions: caller is not authorised");
        _;
    }

    constructor (address payable fundraising) public
    Ownable()
    {
        _fundraising = fundraising;
    }

    function isAllowed(address account) external view returns (bool) {
        return _whitelisted[account];
    }

    function whitelistAccount(address account) external onlyAuthorised {
        _whitelisted[account] = true;
        require(SwarmPoweredFundraise(_fundraising).acceptContributor(account));
        emit AccountWhitelisted(account, msg.sender);
    }

    function unWhitelistAccount(address account) external onlyAuthorised {
        delete _whitelisted[account];
        require(SwarmPoweredFundraise(_fundraising).removeContributor(account));
        emit AccountUnWhitelisted(account, msg.sender);
    }

    function bulkWhitelistAccount(address[] calldata accounts) external onlyAuthorised {
        for (uint256 i = 0; i < accounts.length ; i++) {
            _whitelisted[accounts[i]] = true;
            emit AccountWhitelisted(accounts[i], msg.sender);
        }
    }

    function bulkUnWhitelistAccount(address[] calldata accounts) external onlyAuthorised {
        for (uint256 i = 0; i < accounts.length ; i++) {
            delete _whitelisted[accounts[i]];
            emit AccountUnWhitelisted(accounts[i], msg.sender);
        }
    }
}