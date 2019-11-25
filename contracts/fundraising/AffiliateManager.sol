pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../roles/DelegateRole.sol";

/**
 * @title AffiliateManager
 *
 * Serves to implement all functionality related to managing Affiliates,
 * Affiliate links, etc
 */
contract AffiliateManager is Ownable, DelegateRole {

    struct Affiliate {
        string affiliateLink;
        uint256 percentage;
    }

    mapping(string => address) public affiliateLinks;
    mapping(address => Affiliate) public affiliates;

    /**
     *  Set up an Affiliate. Can be done by the Token Issuer at any time
     *  Setting up the same affiliate again changes his parameters
     *  The contributions are then available to be withdrawn by contributors
     *
     *  @return true on success
     */
    function setupAffiliate(
        address affiliate,
        string calldata affiliateLink,
        uint256 percentage // *100. 5 = 0.5%
    )
        external
        onlyOwner()
        returns (bool)
    {
        affiliates[affiliate].affiliateLink = affiliateLink;
        affiliates[affiliate].percentage = percentage;
        affiliateLinks[affiliateLink] = affiliate;
    }

    /**
     *  Remove an Affiliate. Can be done by the Token Issuer at any time
     *  Any funds he received while active still remain assigned to him.
     *  @param affiliate the address of the affiliate being removed
     *
     *  @return true on success
     */
    function removeAffiliate(
        address affiliate
    )
        external
        onlyOwner()
        returns (bool)
    {
        affiliateLinks[affiliates[affiliate].affiliateLink] = address(0);
        delete(affiliates[affiliate]);
        return true;
    }

    /**
     *  Get information about an Affiliate.
     *  @param affiliateLink the address of the affiliate being removed
     *
     *  @return true on success
     */
    function getAffiliate(
        string calldata affiliateLink
    )
        external
        view
        returns (address, uint256)
    {
        return (
            affiliateLinks[affiliateLink], 
            affiliates[affiliateLinks[affiliateLink]].percentage
        );
    }
}