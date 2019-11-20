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
    }

    function unWhitelistAccount(address account) external onlyAuthorised {
        delete _whitelisted[account];
        require(SwarmPoweredFundraise(_fundraising).rejectContributor(account));
    }

    // @TODO bulk whitelisting
}