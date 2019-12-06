pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICurrencyRegistry.sol";
import "../interfaces/ISRC20.sol";


library Utils {

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
        mapping(address => mapping(address => uint256)) storage bufferedContributions,
        mapping(address => mapping(address => uint256)) storage qualifiedContributions
    )
        external
    {
        refundETHContributions(
            contributor,
            contributionsList,
            bufferedContributions
        );

        refundERC20Contributions(
            contributor,
            contributionsList,
            qualifiedContributions,
            bufferedContributions,
            acceptedCurrencies
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
    function refundETHContributions( // underscore for internal functions
        address contributor,
        mapping(address => Contribution[]) storage contributionsList,
        mapping(address => mapping(address => uint256)) storage bufferedContributions
    )
        internal
    {
        uint256 amountWithdrawn;
        for (uint256 i = 0; i < contributionsList[contributor].length; i++) {
            // @TODO add sums and qualifiedContributions handling !!!!!
            if (contributionsList[contributor][i].currency != address(0))
                continue;
            if (contributionsList[contributor][i].status != ContributionStatus.Refundable)
                continue;
            msg.sender.transfer(contributionsList[contributor][i].amount); // @TODO require()
            amountWithdrawn += contributionsList[contributor][i].amount; // @TODO safemath
            contributionsList[contributor][i].status = ContributionStatus.Refunded;
        }

        delete contributionsList[contributor];

        // withdraw from the buffer too
        uint256 bufferAmount = bufferedContributions[contributor][address(0)];
        if (bufferAmount > 0) {
            msg.sender.transfer(bufferAmount); // @TODO required
            amountWithdrawn += bufferAmount;// @TODO safemath
            bufferedContributions[contributor][address(0)] = 0;
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
        mapping(address => mapping(address => uint256)) storage bufferedContributions
        ) internal returns (uint256) {
        uint256 sum;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];
            uint256 amount = bufferedContributions[contributor][currency];
            if (amount == 0)
                continue;
            require(
                IERC20(currency).transferFrom(address(this), contributor, amount),
                "ERC20 transfer failed!"
            );
            bufferedContributions[contributor][currency] = 0;
            sum += amount;// @TODO safemath
        }
        return sum;
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
    function refundERC20Contributions(
        address contributor,
        mapping(address => Contribution[]) storage contributionsList,
        mapping(address => mapping(address => uint256)) storage qualifiedContributions,
        mapping(address => mapping(address => uint256)) storage bufferedContributions,
        address[] storage acceptedCurrencies
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
            qualifiedContributions[contributor][currency] = 0;

            amount += _refundBufferedERC20( // @TODO safemath
                contributor,
                acceptedCurrencies,
                bufferedContributions
            );
            emit ContributorWithdrawal(contributor, currency, amount);
        }

        delete contributionsList[contributor];
        return true;
    }

    /**
     *  Helper function for getHistoricalBalance()
     *
     *  @param val1 ?
     *  @param val2 ?
     *  @param target ?
     *  @return ?
     */
    function _getLower(uint256 val1, uint256 val2, uint256 target) internal pure returns (uint256) {
        // eliminate warnings
        uint256 dummy1; dummy1 = val2; // @TODO remove
        uint256 dummy2; dummy2 = target; // @TODO remove
        return val1; // @TODO valjda je ovo ok....
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
        // if (_currency == zeroAddr) {
        //     arr = historicalBalanceETH;
        // } else if (_currency == erc20DAI) {
        //     arr = historicalBalanceDAI;
        // } else if (_currency == erc20USDC) {
        //     arr = historicalBalanceUSDC;
        // } else if (_currency == erc20WBTC) {
        //     arr = historicalBalanceWBTC;
        // }
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
                    return _getLower(arr[mid - 1].sequence, arr[mid].sequence, _sequence);
                }
                /* Repeat for left half */
                r = mid;
            } else { // If target is greater than mid
                if (mid < arr.length - 1 && _sequence < arr[mid + 1].sequence) {
                    return _getLower(arr[mid].sequence, arr[mid + 1].sequence, _sequence);
                }
                // update i
                l = mid + 1;
            }
        }
        return arr[mid].balance;
    }

    /**
     *  Loop through the accepted currencies and initiate a withdrawal for
     *  each currency, sending the funds to the Token Issuer
     *
     *  @return true on success
     */
    function withdrawRaisedFunds( // `_`
        address payable issuerWallet,
        address currencyRegistry,
        address[] storage acceptedCurrencies,
        uint256 fundraiseAmountBCY,
        uint256 totalIssuerWithdrawalsBCY,
        mapping(address => uint256) storage qualifiedSums
    )
        internal
        returns (uint256)
    {
        uint256 totalBCY;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++)
            totalBCY += processIssuerWithdrawal(
                issuerWallet,
                acceptedCurrencies[i],
                currencyRegistry,
                totalIssuerWithdrawalsBCY,
                fundraiseAmountBCY,
                qualifiedSums
            );

        return totalBCY;
    }

    /**
     *  Process a single currency withdrawal by the Issuer, making sure not more
     *  than the correct amount is taken
     *
     *  @param currency the currency of the contributions we want to process
     *  @return true on success
     */
    function processIssuerWithdrawal( // `_`
        address payable issuerWallet,
        address currency,
        address currencyRegistry,
        uint256 totalIssuerWithdrawalsBCY,
        uint256 fundraiseAmountBCY,
        mapping(address => uint256) storage qualifiedSums
    )
        internal
        returns (uint256)
    {
        uint256 amount = qualifiedSums[currency];
        uint256 amountBCY = ICurrencyRegistry(currencyRegistry).toBCY(qualifiedSums[currency], currency);
        if (totalIssuerWithdrawalsBCY + amountBCY > fundraiseAmountBCY) {
            amount = qualifiedSums[currency] *
                     (fundraiseAmountBCY - totalIssuerWithdrawalsBCY) / amountBCY;
            amountBCY = ICurrencyRegistry(currencyRegistry).toBCY(amount, currency);
        }

        qualifiedSums[currency] -= amount;

        if (currency == address(0))
            issuerWallet.transfer(amount);
        else
            IERC20(currency).transfer(issuerWallet, amount);

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
            sum += ICurrencyRegistry(currencyRegistry).toBCY(
                getHistoricalBalance(seq, currency, historicalBalance),
                currency
            );
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
        // @TODO make this function restartable and return how many tokens are left to claim

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
            if (historicalBalanceBCY + contributionBCY < fundraiseAmountBCY) { //@TODO safe math
                totalContributorAcceptedBCY += contributionBCY; //@TODO safe math
            } else { // ...or just a part of it
                totalContributorAcceptedBCY += fundraiseAmountBCY - historicalBalanceBCY; //@TODO safe math
                uint256 refund = historicalBalanceBCY + contributionBCY - fundraiseAmountBCY; //@TODO safe math
                bufferedContributions[msg.sender][contributionsList[msg.sender][i].currency] += refund; //@TODO safe math
                break; // we've hit the end, break from the loop
            }
        }

        uint256 tokenAllotment = totalContributorAcceptedBCY / SRC20tokenPriceBCY; //@TODO safe math, AND what happend with funds that are not allocated (/ is cellular division)
        ISRC20(src20).transfer(msg.sender, tokenAllotment);
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
        address[] storage acceptedCurrencies,
        mapping(address => mapping(address => uint256)) storage qualifiedContributions
    )
        public
        returns (uint256)
    {
        uint256 sum;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];
            sum += ICurrencyRegistry(currencyRegistry).toBCY(qualifiedContributions[contributor][currency], currency);
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
            qualifiedContributions[contributor][currency] -= amount;
            if (contributionsList[contributor][i].status != ContributionStatus.Refundable)
                continue;
            contributionsList[contributor][i].status = ContributionStatus.Refunded;
            bufferedContributions[contributor][currency] += amount;
        }

        // remove his contributions from the queue
        delete(contributionsList[msg.sender]);
        emit ContributorRemoved(contributor);

        return true;
    }

    /**
     *  Loop through the accepted currencies and lock the exchange rates
     *  between each of them and BCY
     *  @return true on success
     */
    function lockExchangeRates(
        address currencyRegistry,
        address[] storage acceptedCurrencies,
        mapping(address => uint256) storage lockedExchangeRate
    )
        internal
        returns (bool)
    {
        // @TODO check with business if this logic is acceptable
        for (uint256 i = 0; i < acceptedCurrencies.length; i++)
            lockedExchangeRate[acceptedCurrencies[i]] =
                ICurrencyRegistry(currencyRegistry).toBCY(1, acceptedCurrencies[i]); // @TODO 1 should be multiplied with decimals

        return true;
    }

}
