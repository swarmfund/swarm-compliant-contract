pragma solidity ^0.5.0;

import "../interfaces/IContributorRestrictions.sol";
import "./ContributorWhitelist.sol";
import "../fundraising/SwarmPoweredFundraise.sol";
import "../roles/DelegateRole.sol";

/**
 * @title ContributorRestrictions
 *
 * Serves to implement all the various restrictions that a Fundraise can have.
 * A Fundraise contract always points to only one ContributorRestrictions contract.
 * The owner of the Fundraise contract sets up ContributorRestrictions contract at
 * the beginning of the fundraise.
 */
contract ContributorRestrictions is IContributorRestrictions, ContributorWhitelist, DelegateRole {

    address payable fundraise;
    uint256 public maxContributors;

    modifier onlyAuthorised() {
        require(msg.sender == owner() ||
                msg.sender == fundraise ||
                _hasDelegate(msg.sender),
                "ContributorRestrictions: caller is not authorised");
        _;
    }

    constructor (
        address payable fundraiseContract,
        uint256 maxNumContributors
    )
        public
        Ownable()
    {
        fundraise = fundraiseContract;
        maxContributors = maxNumContributors;
    }

    // checkRestrictions
    function isAllowed(address account) external view returns (bool) {
        // if(
        //     _whitelisted[account] &&
        //     maxContributors == 0 ?
        //         true :
        //         SwarmPoweredFundraise(fundraise).numberOfContributors() < maxContributors
        //     )
        //     return true;
        // else
        //     return false;
        require(_whitelisted[account], "Account not on whitelist!");
        require(
            maxContributors == 0 ?
                 true :
                 SwarmPoweredFundraise(fundraise).numberOfContributors() < maxContributors,
            "Max number of contributors exceeded!"
        );
    }

    function whitelistAccount(address account) external onlyAuthorised {
        _whitelisted[account] = true;
        require(
            SwarmPoweredFundraise(fundraise).acceptContributor(account),
            "Whitelisting failed on processing contributions!"
        );
        emit AccountWhitelisted(account, msg.sender);
    }

    function unWhitelistAccount(address account) external onlyAuthorised {
        delete _whitelisted[account];
        require(
            SwarmPoweredFundraise(fundraise).removeContributor(account),
            "UnWhitelisting failed on processing contributions!"
        );
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