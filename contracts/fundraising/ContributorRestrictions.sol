pragma solidity ^0.5.0;

import "../interfaces/IContributionRestrictions.sol";
import "./ContributorWhitelist.sol";

contract ContributorRestrictions is IContributionRestrictions, ContributorWhitelist {

    address _fundraising;

    constructor (address fundraising) public
    Ownable()
    {
        _fundraising = fundraising;
    }

    function checkContributor(address account) external view returns (bool) {
        return true;
    }
}