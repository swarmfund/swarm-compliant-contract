pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICurrencyRegistry.sol";
import "../interfaces/ISRC20.sol";


library Utils {

    using SafeMath for uint256;

    event ContributorWithdrawal(address contributorWallet, address currency, uint256 amount);
    event IssuerWithdrawal(address issuerWallet, address currency, uint256 amount);
    event SRC20TokensClaimed(address indexed by, uint256 tokenAllotment);
    event ContributorRemoved(address contributor);

    enum ContributionStatus { Refundable, Refunded, Accepted, Offchain }

    struct Balance {
        uint256 sequence;
        uint256 balance;
    }

    struct Contribution {
        address currency;
        uint256 amount;
        uint256 sequence;
        ContributionStatus status;
    }

    /**
    *  Sends to contributor all his contributions, both ETH and ERC20
    *
    *  @param contributor address of the contributor we want to withdraw
    *                     the ETH for/to
    *  @return true on success
    */
    function getRefund(
        address contributor,
        address[] storage acceptedCurrencies,
        mapping(address => Contribution[]) storage contributionsList,
        mapping(address => mapping(address => uint256)) storage qualifiedContributions,
        mapping(address => mapping(address => uint256)) storage bufferedContributions,
        mapping(address => uint256) storage qualifiedSums,
        mapping(address => uint256) storage bufferedSums
    )
        external
    {
        _refundETHContributions(
            contributor,
            contributionsList,
            qualifiedContributions,
            bufferedContributions,
            qualifiedSums,
            bufferedSums
        );

        _refundERC20Contributions(
            contributor,
            acceptedCurrencies,
            contributionsList,
            qualifiedContributions,
            bufferedContributions,
            qualifiedSums,
            bufferedSums
        );
    }

    /**
    *  Sends to contributor all his ETH contributions, if this is permitted
    *  by the state of the Fundraise. We only allow withdrawing of the contributions
    *  that are still buffered/pending, or are qualified but not: Refunded, Accepted
    *  or Offchain
    *
    *  @param contributor address of the contributor we want to withdraw
    *                     the ETH for/to
    *  @return true on success
    */
    function _refundETHContributions( // underscore for internal functions
        address contributor,
        mapping(address => Contribution[]) storage contributionsList,
        mapping(address => mapping(address => uint256)) storage qualifiedContributions,
        mapping(address => mapping(address => uint256)) storage bufferedContributions,
        mapping(address => uint256) storage qualifiedSums,
        mapping(address => uint256) storage bufferedSums
    )
        internal
    {
        uint256 amountWithdrawn;
        for (uint256 i = 0; i < contributionsList[contributor].length; i++) {
            if (contributionsList[contributor][i].currency != address(0))
                continue;
            if (contributionsList[contributor][i].status != ContributionStatus.Refundable)
                continue;
            msg.sender.transfer(contributionsList[contributor][i].amount);
            amountWithdrawn = amountWithdrawn.add(contributionsList[contributor][i].amount);
            contributionsList[contributor][i].status = ContributionStatus.Refunded;
        }
        delete contributionsList[contributor];

        qualifiedContributions[contributor][address(0)] = qualifiedContributions[contributor][address(0)]
            .sub(amountWithdrawn);
        qualifiedSums[address(0)] = qualifiedSums[address(0)].sub(amountWithdrawn);

        // withdraw from the buffer too
        uint256 bufferAmount = bufferedContributions[contributor][address(0)];
        if (bufferAmount > 0) {
            msg.sender.transfer(bufferAmount);
            amountWithdrawn = amountWithdrawn.add(bufferAmount);
            bufferedContributions[contributor][address(0)] = 0;
            bufferedSums[address(0)] = bufferedSums[address(0)].sub(bufferAmount);
        }

        emit ContributorWithdrawal(contributor, address(0), amountWithdrawn);
    }

    /**
     *  Helper function for refunding a particular contributor his buffered
     *  ERC20 tokens. This function doesn't handle ETH, nor qualified
     *  contributions
     *
     *  @param contributor the price of individual token, in BCY
     *  @return the amount that was refunded
     */
    function _refundBufferedERC20(
            address contributor,
            address[] storage acceptedCurrencies,
            mapping(address => mapping(address => uint256)) storage bufferedContributions,
            mapping(address => uint256) storage bufferedSums
        ) 
            internal 
            returns (bool) 
        {
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];
            uint256 amount = bufferedContributions[contributor][currency];
            if (amount == 0)
                continue;
            require(
                IERC20(currency).transferFrom(address(this), contributor, amount),
                "ERC20 transfer failed!"
            );
            bufferedContributions[contributor][currency] = bufferedContributions[contributor][currency]
                .sub(amount);
            bufferedSums[currency] = bufferedSums[currency].sub(amount);
            emit ContributorWithdrawal(contributor, currency, amount);
        }
        return true;
    }

    /**
     *  Sends to contributor all his ERC20 tokens, if this is permitted
     *  by the state of the Fundraise. We only allow withdrawing of the contributions
     *  that are still buffered/pending, or are qualified but not: Refunded, Accepted
     *  or Offchain
     *
     *  @param contributor address of the contributor we want to withdraw
     *                     the ERC20 tokens/currencies for/to
     *  @return true on success
     */
    function _refundERC20Contributions(
        address contributor,
        address[] storage acceptedCurrencies,
        mapping(address => Contribution[]) storage contributionsList,
        mapping(address => mapping(address => uint256)) storage qualifiedContributions,
        mapping(address => mapping(address => uint256)) storage bufferedContributions,
        mapping(address => uint256) storage qualifiedSums,
        mapping(address => uint256) storage bufferedSums
    )
        internal
        returns (bool)
    {
        // We must use a loop instead of just looking at qualifiedContributions because
        // some contributions could have been offchain and those must not be withdrawable
        for (uint256 i = 0; i < contributionsList[contributor].length; i++) {
            uint256 amount = contributionsList[contributor][i].amount;
            address currency = contributionsList[contributor][i].currency;
            ContributionStatus status = contributionsList[contributor][i].status;

            if (currency == address(0) || status != ContributionStatus.Refundable)
                continue;

            require(
                IERC20(currency).transferFrom(address(this), contributor, amount),
                "ERC20 transfer failed!"
            );

            contributionsList[contributor][i].status = ContributionStatus.Refunded;
            qualifiedContributions[contributor][currency] = qualifiedContributions[contributor][currency]
                .sub(amount);
            qualifiedSums[currency] = qualifiedSums[currency].sub(amount);

            emit ContributorWithdrawal(contributor, currency, amount);
        }

        delete contributionsList[contributor];

        _refundBufferedERC20(
            contributor,
            acceptedCurrencies,
            bufferedContributions,
            bufferedSums
        );

        return true;
    }

    /**
     *  Return the balance in _currency at the time of the _sequence
     *  @dev using binary search
     *  @param _sequence the queue position we are looking for
     *  @param _currency the currency we are looking for
     *  @return the historical balance in _currency at the time of the _sequence
     */
    function getHistoricalBalance(
        uint256 _sequence,
        address _currency,
        mapping(address => Balance[]) storage historicalBalance
    )
        public
        view
        returns (uint256)
    {
        Balance[] memory arr = historicalBalance[_currency];

        uint256 l;
        uint256 r = arr.length;
        uint256 mid;
        while (l < r) {
            mid = l + (r - l) / 2;
            // Check if x is present at mid
            if (arr[mid].sequence == _sequence)
                return arr[mid].balance;
            if (_sequence < arr[mid].sequence) {
                // If target is greater than previous
                // to mid, return closest of two
                if (mid > 0 && _sequence > arr[mid - 1].sequence) {
                    // return _getLower(arr[mid - 1].sequence, arr[mid].sequence, _sequence);
                    return arr[mid - 1].sequence;
                }
                /* Repeat for left half */
                r = mid;
            } else { // If target is greater than mid
                if (mid < arr.length - 1 && _sequence < arr[mid + 1].sequence) {
                    // return _getLower(arr[mid].sequence, arr[mid + 1].sequence, _sequence);
                    return arr[mid].sequence;
                }
                // update i
                l = mid + 1;
            }
        }
        return arr[mid].balance;
    }

    // /**
    //  *  Loop through the accepted currencies and initiate a withdrawal for
    //  *  each currency, sending the funds to the Token Issuer
    //  *
    //  *  @return true on success
    //  */
    // function withdrawRaisedFunds(
    //     address payable issuerWallet,
    //     address currencyRegistry,
    //     address[] storage acceptedCurrencies,
    //     uint256 fundraiseAmountBCY,
    //     uint256 totalIssuerWithdrawalsBCY,
    //     mapping(address => uint256) storage qualifiedSums
    // )
    //     external
    //     returns (uint256)
    // {
    //     uint256 totalBCY;
    //     for (uint256 i = 0; i < acceptedCurrencies.length; i++)
    //         totalBCY += processIssuerWithdrawal(
    //             issuerWallet,
    //             acceptedCurrencies[i],
    //             currencyRegistry,
    //             totalIssuerWithdrawalsBCY,
    //             fundraiseAmountBCY,
    //             qualifiedSums
    //         );

    //     return totalBCY;
    // }

    /**
     *  Process a single currency withdrawal by the Issuer, making sure not more
     *  than the correct amount is taken
     *
     *  @param currency the currency of the contributions we want to process
     *  @return true on success
     */
    function processIssuerWithdrawal(
        address payable issuerWallet,
        address currency,
        address currencyRegistry,
        uint256 totalIssuerWithdrawalsBCY,
        uint256 fundraiseAmountBCY,
        mapping(address => uint256) storage qualifiedSums
    )
        public
        returns (uint256)
    {
        uint256 amount = qualifiedSums[currency];
        uint256 amountBCY = ICurrencyRegistry(currencyRegistry).toBCY(qualifiedSums[currency], currency);
        if (totalIssuerWithdrawalsBCY.add(amountBCY) > fundraiseAmountBCY) {
            amount = qualifiedSums[currency]
                     .mul(fundraiseAmountBCY.sub(totalIssuerWithdrawalsBCY)).div(amountBCY);
            amountBCY = ICurrencyRegistry(currencyRegistry).toBCY(amount, currency);
        }

        qualifiedSums[currency] = qualifiedSums[currency].sub(amount);

        if (currency == address(0))
            issuerWallet.transfer(amount);
        else
            require(IERC20(currency).transfer(issuerWallet, amount), 'ERC20 transfer failed');

        emit IssuerWithdrawal(issuerWallet, currency, amount);
        return amountBCY;
    }

    /**
     *  Loop through the accepted currencies and return the sum of historical
     *  balances at the time of the seq, converted to base currency
     *  @param seq the sequence which we want historical balances for
     *  @return sum of all historical balances (in all currencies), at seq time,
     *          converted to BCY
     */
    function getHistoricalBalanceBCY(
        uint256 seq,
        address currencyRegistry,
        address[] storage acceptedCurrencies,
        mapping(address => Balance[]) storage historicalBalance
    )
        public
        returns (uint256)
    {
        uint256 sum;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];
            sum = sum.add(ICurrencyRegistry(currencyRegistry).toBCY(
                getHistoricalBalance(seq, currency, historicalBalance),
                currency
            ));
        }
        return sum;
    }

    /**
     *  Allow the caller, if he is eligible, to withdraw his SRC20 tokens once
     *  they have been minted
     *
     *  @return true on success
     */
    function claimTokens(
        address src20,
        address currencyRegistry,
        uint256 SRC20tokenPriceBCY,
        uint256 fundraiseAmountBCY,
        address[] storage acceptedCurrencies,
        mapping(address => Contribution[]) storage contributionsList,
        mapping(address => Balance[]) storage historicalBalance,
        mapping(address => mapping(address => uint256)) storage bufferedContributions
    )
        external
        returns (uint256)
    {
        // go through a contributor's contributions, sum up those qualified for
        // converting into tokens
        uint256 totalContributorAcceptedBCY = 0;
        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            // to make sure we pay him out only once
            if (contributionsList[msg.sender][i].status != ContributionStatus.Refundable)
                continue;

            // we change to accepted... but could also be deleting
            contributionsList[msg.sender][i].status = ContributionStatus.Accepted;

            uint256 contributionBCY = ICurrencyRegistry(currencyRegistry).toBCY(
                contributionsList[msg.sender][i].amount,
                contributionsList[msg.sender][i].currency
            );

            uint256 historicalBalanceBCY = getHistoricalBalanceBCY(
                contributionsList[msg.sender][i].sequence,
                currencyRegistry,
                acceptedCurrencies,
                historicalBalance
            );
            // Whether we take the whole amount...
            if (historicalBalanceBCY.add(contributionBCY) < fundraiseAmountBCY) {
                totalContributorAcceptedBCY = totalContributorAcceptedBCY.add(contributionBCY);
            } else { // ...or just a part of it
                totalContributorAcceptedBCY = totalContributorAcceptedBCY
                    .add(fundraiseAmountBCY.sub(historicalBalanceBCY));
                uint256 refund = historicalBalanceBCY.add(contributionBCY.sub(fundraiseAmountBCY));
                bufferedContributions[msg.sender][contributionsList[msg.sender][i].currency] = 
                bufferedContributions[msg.sender][contributionsList[msg.sender][i].currency].add(refund);
                break; // we've hit the end, break from the loop
            }
        }

        uint256 tokenAllotment = totalContributorAcceptedBCY.div(SRC20tokenPriceBCY);

        require(
            ISRC20(src20).transfer(msg.sender, tokenAllotment),
            'Failed to transfer SRC20!'
        );
        emit SRC20TokensClaimed(msg.sender, tokenAllotment);
        return 0;
    }

    /**
     *  Loop through currencies and get the value (in BCY) of all the
     *  contributor's qualified contributions
     *  @param contributor the address of the contributor
     *  @return sum of all qualified contributions for the contributor,
     *          converted to BCY
     */
    function getQualifiedContributionsBCY(
        address contributor,
        address currencyRegistry,
        mapping(address => mapping(address => uint256)) storage qualifiedContributions
    )
        external
        returns (uint256)
    {
        uint256 sum;
        address[] memory acceptedCurrencies = ICurrencyRegistry(currencyRegistry).getAcceptedCurrencies();
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];
            sum = sum.add(
                ICurrencyRegistry(currencyRegistry).toBCY(
                    qualifiedContributions[contributor][currency], currency
                )
            );
        }
        return sum;
    }

    /**
     *  Loop through currencies and get the value (in BCY) of all the
     *  qualified contributions
     *
     *  @return sum of all qualified contributions, in all currencies,
     *          converted to BCY
     */
    function getQualifiedSumsBCY(
        address currencyRegistry,
        address[] storage acceptedCurrencies,
        mapping(address => uint256) storage qualifiedSums
    ) 
        public 
        returns (uint256)
    {
        uint256 sum;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];
            sum = sum.add(ICurrencyRegistry(currencyRegistry).toBCY(qualifiedSums[currency], currency));
        }
        return sum;
    }

    /**
     *  Worker function for removeContributor()
     *  Removes the contributor by removing all his qualified contributions
     *  They will be moved into his buffered contributions, from where
     *  he will be able to withdraw them, once fundraise is finished
     *
     *  @param contributor the contributor we want to remove
     *  @return true on success
     */
    function removeContributor(
        address contributor,
        mapping(address => Contribution[]) storage contributionsList,
        mapping(address => mapping(address => uint256)) storage bufferedContributions,
        mapping(address => mapping(address => uint256)) storage qualifiedContributions
    )
        external
        returns (bool)
    {
        // remove all his qualified contributions back into the buffered, so he can withdraw them
        // NOTE: except for the offchain contributions, which he must not be allowed to withdraw!
        for (uint256 i = 0; i < contributionsList[contributor].length; i++) {
            address currency = contributionsList[contributor][i].currency;
            uint256 amount = contributionsList[contributor][i].amount;
            qualifiedContributions[contributor][currency] = qualifiedContributions[contributor][currency]
                .sub(amount);
            if (contributionsList[contributor][i].status != ContributionStatus.Refundable)
                continue;
            contributionsList[contributor][i].status = ContributionStatus.Refunded;
            bufferedContributions[contributor][currency] = bufferedContributions[contributor][currency]
                .sub(amount);
        }

        // remove his contributions from the queue
        delete(contributionsList[msg.sender]);
        emit ContributorRemoved(contributor);

        return true;
    }

}
