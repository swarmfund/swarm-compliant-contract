pragma solidity ^0.5.0;

import "../interfaces/IContributorRestrictions.sol";
import "./ContributorWhitelist.sol";
import "../fundraising/SwarmPoweredFundraise.sol";

contract ContributorRestrictions is IContributorRestrictions, ContributorWhitelist {

    address payable _fundraising;

    constructor (address payable fundraising) public
    Ownable()
    {
        _fundraising = fundraising;
    }

    function checkContributor(address account) external view returns (bool) {
        return _whitelisted[account];
    }

    function whitelistAccount(address account) external onlyOwner {
        require(SwarmPoweredFundraise(_fundraising).acceptContributor(account));
        _whitelisted[account] = true;
    }

    function unWhitelistAccount(address account) external onlyOwner {
        require(SwarmPoweredFundraise(_fundraising).rejectContributor(account));
        delete _whitelisted[account];
    }

    // @TODO bulk whitelisting
}