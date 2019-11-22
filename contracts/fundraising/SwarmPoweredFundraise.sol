pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "../interfaces/ISRC20.sol";
import "../interfaces/IUniswap.sol";
import "../interfaces/IGetRateMinter.sol";
import "../interfaces/ICurrencyRegistry.sol";
import "../interfaces/IContributionRules.sol";
import "../interfaces/IIssuerStakeOfferPool.sol";
import "../interfaces/IContributorRestrictions.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract SwarmPoweredFundraise {

    address private owner;

    using SafeMath for uint256;
    // @TODO convert all math in the contract to SafeMath once happy with logic

    event ContributionReceived(address indexed from, uint256 amount, uint256 sequence, address baseCurrency);
    event SRC20TokensClaimed(address indexed by, uint256 tokenAllotment);
    event ContributorWithdrawal(address contributorWallet, address currency, uint256 amount);
    event IssuerWithdrawal(address issuerWallet, address currency, uint256 amount);
    event ContributorRemoved(address contributor);
    event ContributorAccepted(address contributor);

    // Setup variables that never change
    string public label;

    uint256 public startDate;
    uint256 public endDate;
    uint256 public minAmountBCY;
    uint256 public maxAmountBCY;
    uint256 public preSaleAmountBCY; // the amount raised in the Presale phase, in base currency
    uint256 public preSaleTokensReserved; // the number of SRC20 tokens reserved for the presale
    // variables that can change over time
    uint256 public softCapBCY;
    uint256 public hardCapBCY;
    uint256 public SRC20tokenPriceBCY;
    uint256 public SRC20tokenSupply; // @TODO rethink the name
    uint256 public fundraiseAmountBCY;
    uint256 public sequence;
    uint256 public expirationTime = 7776000; // default: 60 * 60 * 24 * 90 = ~3months
    uint256 public totalIssuerWithdrawalsBCY;

    // @TODO see about this...
    address public ETH = address(0);

    address public src20;
    address public contributionRules;
    address public contributorRestrictions;
    address public SwarmERC20;
    address public minter;
    address payable issuerWallet;
    address public currencyRegistry;
    ICurrencyRegistry cr;
    address[] acceptedCurrencies;

    bool public isFinished;
    bool public contributionsLocking = true;
    bool public contributionsLocked = true;
    bool public offchainContributionsAllowed = false;
    bool public setupCompleted = false;

    uint256 public numberOfContributors;

    struct Affiliate {
        address account;
        uint256 percentage;
        uint256 minAmount;
    }
    // Affiliate links
    mapping(string => Affiliate) affiliates;

    // State variables that change over time
    enum ContributionStatus { Refundable, Refunded, Accepted, Offchain }

    struct Contribution {
        address currency;
        uint256 amount;
        uint256 sequence; // @TODO rethink the name, maybe queuePosition
        ContributionStatus status;
    }

    // @TODO maybe rename to contributionsQueue?
    // per contributor, iterable list of his contributions
    mapping(address => Contribution[]) contributionsList;

    // @TODO think about naming: pending vs buffered
    // per contributor and currency, pending amount
    mapping(address => mapping(address => uint256)) public bufferedContributions;

    // per contributor and currency, qualified amount
    // a qualified amount is amount that has passed min/max checks and has been placed in the queue
    mapping(address => mapping(address => uint256)) public qualifiedContributions;

    // per currency, total qualified sums
    mapping(address => uint256) public qualifiedSums;

    // per currency, its final exchange rate to BCY
    mapping(address => uint256) lockedExchangeRate;

    //currencies(currencies).currency[DAI].exchangeContract
    struct Balance {
        uint256 sequence;
        uint256 balance;
    }
    mapping(address => Balance[]) historicalBalance;

    /**
     * Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    // only allow the external contract that handles restrictions to call
    modifier onlyContributorRestrictions {
        require(msg.sender == contributorRestrictions, "Caller not Contributor Restrictions contract!");
        _;
    }

    // only allow the currencies we accept
    modifier onlyAcceptedCurrencies(address currency) {
        require(
            ICurrencyRegistry(currencyRegistry).isAccepted(currency),
            "Unsupported contribution currency"
        );
        _;
    }

    // only allow if the fundraise has started and is ongoing
    modifier ongoing {
        require(SRC20tokenPriceBCY != 0 || SRC20tokenSupply != 0, "Token price or supply are not set");
        require(setupCompleted, "Fundraise setup not completed!");
        require(isFinished == false, "Fundraise has finished!");
        require(block.timestamp >= startDate, "Fundraise did not start yet!");
        require(block.timestamp <= endDate, "Fundraise has ended");
        _;
    }

    /**
     *  Pass all the most important parameters that define the Fundraise
     *  All variables cannot be in the constructor because we get "stack too deep" error
     *  After deployment setupContract() function needs to be called to set them up.
     */
    constructor(
        string memory _label,
        address _src20,
        address _currencyRegistry,
        uint256 _SRC20tokenSupply,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _softCapBCY,
        uint256 _hardCapBCY
    )
    public
    {
        owner = msg.sender;
        label = _label;
        src20 = _src20;
        cr = ICurrencyRegistry(_currencyRegistry);
        acceptedCurrencies = cr.getAcceptedCurrencies();
        currencyRegistry = _currencyRegistry;
        SRC20tokenSupply = _SRC20tokenSupply;
        startDate = _startDate; 
        endDate = _endDate;
        softCapBCY = _softCapBCY;
        hardCapBCY = _hardCapBCY;
    }

    /**
     *  Invoked when a contributor simply sends ETH to the contract
     */
    function() external payable {
        // We want the Token Issuer to be able to send ETH to the contract even after
        // the fundraise has finished. He might need to get SWM via ISOP
        require(
            isFinished == false || msg.sender == owner,
            "Only owner can send ETH if fundraise has finished!"
        );

        _contribute(msg.sender, ETH, msg.value, "");
    }

    /**
     *  Set up additional parameters that didn't fit in the constructor
     *  All variables cannot be in the constructor because we get "stack too deep" error
     */
    function setupContract(
        uint256 _minAmountBCY,
        uint256 _maxAmountBCY
    )
    external
    onlyOwner()
    {
        minAmountBCY = _minAmountBCY;
        maxAmountBCY = _maxAmountBCY;
        setupCompleted = true;
    }

    /**
     *  Set the contract with contribution rules
     *
     *  @param rules the contract with the rules
     *  @return true on success
     */
    function setContributionRules(address rules) external returns (bool) {
        require(contributionRules != address(0), "Contribution rules already set");
        contributionRules = rules;
        return true;
    }

    /**
     *  Unlock the contributions so that they can be withdrawn by contributors
     *  This can be called by anyone if/when the fundraise expires
     *
     *  @return true on success
     */
    function unlockContributions() external returns (bool) {
        require(
            block.timestamp > endDate.add(expirationTime),
            "Cannot unlock contributios: wait until expiration"
        );
        contributionsLocked = false;
        return true;
    }

    /**
     *  Loop through currencies and get the value (in BCY) of all the
     *  contributor's buffered contributions
     *  @param contributor the address of the contributor
     *  @return sum of all buffered contributions for the contributor,
     *          converted to BCY
     */
    function getBufferedContributionsBCY (address contributor) public returns (uint256) {
        uint256 sum;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];            
            sum += cr.toBCY(bufferedContributions[contributor][currency], currency);
        }
        return sum;
    }

    /**
     *  Loop through currencies and get the value (in BCY) of all the
     *  contributor's qualified contributions
     *  @param contributor the address of the contributor
     *  @return sum of all qualified contributions for the contributor,
     *          converted to BCY
     */
    function getQualifiedContributionsBCY(address contributor) public returns (uint256) {
        uint256 sum;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];            
            sum += cr.toBCY(qualifiedContributions[contributor][currency], currency);
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
    function getQualifiedSumsBCY() public returns (uint256) {
        uint256 sum;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];            
            sum += cr.toBCY(qualifiedSums[currency], currency);
        }
        return sum;
    }

    /**
     *  Loop through the accepted currencies and return the sum of historical
     *  balances at the time of the seq, converted to base currency
     *  @param seq the sequence which we want historical balances for
     *  @return sum of all historical balances (in all currencies), at seq time,
     *          converted to BCY
     */
    function getHistoricalBalanceBCY(uint256 seq) public returns (uint256) {
        uint256 sum;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];            
            sum += cr.toBCY(getHistoricalBalance(seq, currency), currency);
        }
        return sum;
    }

    /**
     *  Loop through all the buffers (four now, but could be many more eventually)
     *  and turn them into qualified contributions.
     *
     *  NOTE: this skips the minAmount checks!
     *  NOTE: the maxAmount check is still performed
     *
     *  @param contributor the address of the contributor we are processing
     *         buffered contributions for
     *  @return 0 if all the contributions were accepted, overflow if some were above
     *          maxAmount and were not added
     */
    function _addBufferedContributions(address contributor) internal returns (uint256) {
        uint256 sum;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];            
            sum += _addContribution(contributor, currency, bufferedContributions[contributor][currency]);
        }
        return sum;
    }

    /**
     *  Loop through the accepted currencies and initiate a withdrawal for
     *  each currency, sending the funds to the Token Issuer
     *
     *  @return true on success
     */
    function _withdrawRaisedFunds() internal returns (bool) {

        for (uint256 i = 0; i < acceptedCurrencies.length; i++)
            _processIssuerWithdrawal(acceptedCurrencies[i]);

        return true;
    }

    /**
     *  Loop through the accepted currencies and lock the exchange rates
     *  between each of them and BCY
     *  @return true on success
     */
    function _lockExchangeRates() internal returns (bool) {
        // @TODO check with business if this logic is acceptable
        for (uint256 i = 0; i < acceptedCurrencies.length; i++)
            lockedExchangeRate[acceptedCurrencies[i]] = 
                cr.toBCY(1, acceptedCurrencies[i]);

        return true;
    }

    /**
     *  Worker function that adds a contribution to the list of contributions
     *  and updates all the relevant sums and balances
     *
     *  NOTE: for the processing of buffers we can't have min/max checking in this function
     *  because when processing buffers we accept small amounts step by step.
     *  maybe add another more basic function: addContributionMinMax, addContribution
     *
     *  @param contributor the address of the contributor
     *  @param currency the currency of the amount being added
     *  @param amount the amount being added
     *  @return 0 if the whole contribution was accepted, the overflow if it was above
     *          maxAmount and only a part of it was accepted
     */
    function _addContribution(
        address contributor,
        address currency,
        uint256 amount
    )
        internal
        onlyAcceptedCurrencies(currency)
        returns (uint256)
    {
        // convert the coming contribution to BCY
        uint256 amountBCY = cr.toBCY(amount, currency);

        // get the value in BCY of his previous qualified contributions
        uint256 previousContributionsBCY = getQualifiedContributionsBCY(contributor);

        // get the total with this contribution
        uint256 contributionsBCY = previousContributionsBCY + amountBCY;

        // if we are still below the minimum, return
        //if (contributionsBCY < minAmountBCY)
        //    return;

        // if we are above with previous amount, due to exchange rate fluctuations, return
        if (previousContributionsBCY >= maxAmountBCY)
            return amount;

        // if we cross the max, take only a portion of the contribution, via a percentage
        uint256 qualifiedAmount = amount;
        if (contributionsBCY > maxAmountBCY)
            qualifiedAmount = amount * (maxAmountBCY - previousContributionsBCY) / amountBCY;

        // leave the extra in the buffer, get the all the rest
        bufferedContributions[contributor][currency] -= qualifiedAmount;

        // if this is the first time he's contributing, increase the contributor counter
        if (contributionsList[contributor].length == 0)
            numberOfContributors++;

        Contribution memory c;
        sequence++;
        c.currency = currency;
        c.amount = qualifiedAmount;
        c.sequence = sequence;
        c.status = ContributionStatus.Refundable;
        contributionsList[contributor].push(c);

        // adjust the global and historical sums
        qualifiedContributions[contributor][currency] += qualifiedAmount;
        qualifiedSums[currency] += qualifiedAmount;
        Balance memory balance;
        balance.sequence = sequence;
        balance.balance = qualifiedSums[currency];
        historicalBalance[currency].push(balance);

        emit ContributionReceived(contributor, qualifiedAmount, sequence, currency);
        return qualifiedAmount - amount;
    }

    /**
     *  Allows Token Issuer to add a contribution to the fundraise contract's accounting
     *  in the case he received an offchain contribution, for example
     *
     *  @param contributor the address of the contributor we want to add
     *  @param currency the currency of the contribution we are adding
     *  @param amount the amount of the contribution we are adding
     *  @return true on success
     */
    function addOffchainContribution(
        address contributor,
        address currency,
        uint256 amount
    )
        public
        onlyOwner()
        ongoing
        onlyAcceptedCurrencies(currency)
        returns (bool)
    {
        require(offchainContributionsAllowed, "Offchain contribution failed: not allowed by setup!");

        // whitelist the contributor
        IContributorRestrictions(contributorRestrictions).whitelistAccount(contributor);

        // we've just whitelisted him but still need to check
        // for example it could be that max number of contributors has been exceeded
        IContributorRestrictions(contributorRestrictions).isAllowed(contributor);

        // add the contribution to the buffer
        bufferedContributions[contributor][currency] += amount;

        // add the contribution to the queue
        uint256 overMax = _addContribution(contributor, currency, amount);
        // the extra amount must never be refundable
        bufferedContributions[contributor][currency] -= overMax;

        // set up the contribution we have just added so that it can not be withdrawn
        contributionsList[contributor][contributionsList[contributor].length - 1]
                         .status = ContributionStatus.Offchain;
    }

    /**
     *  contribute ERC20 without an affiliate link
     *
     *  @param erc20 the currency of the contribution
     *  @param amount the amount of the contribution
     *  @return true on success
     */
    function contribute(
        address erc20,
        uint256 amount
    )
        public
        ongoing
        onlyAcceptedCurrencies(erc20)
        returns (bool)
    {
        _contribute(msg.sender, erc20, amount, "");
    }

    /**
     *  contribute ERC20 with an affiliate link
     *
     *  @param erc20 the currency of the contribution
     *  @param amount the amount of the contribution
     *  @param affiliateLink (optional) affiliate link used
     *  @return true on success
     */
    function contribute(
        address erc20,
        uint256 amount,
        string memory affiliateLink
    )
        public
        ongoing
        onlyAcceptedCurrencies(erc20)
        returns (bool)
    {
        require(
            IERC20(erc20).transferFrom(msg.sender, address(this), amount),
            "Contribution failed: ERC20 transfer failed!"
        );

        _contribute(msg.sender, erc20, amount, affiliateLink);
    }

    /**
     *  Worker function for both ETH and ERC20 contributions
     *
     *  @param contributor the address of the contributor
     *  @param currency the currency of the contribution
     *  @param amount the amount of the contribution
     *  @param affiliateLink (optional) affiliate link used
     *  @return true on success
     */
    function _contribute(
        address contributor,
        address currency,
        uint256 amount,
        string memory affiliateLink
    )
        internal
        returns (bool)
    {
        if (bytes(affiliateLink).length > 0) {
            // send the reward to referee's buffer
            Affiliate memory affiliate = affiliates[affiliateLink];
            bufferedContributions[affiliate.account][currency] += amount * affiliate.percentage;
            // adjust the amount
            amount -= amount * affiliate.percentage;
        }

        // add the contribution to the buffer
        bufferedContributions[contributor][currency] += amount;

        // Check if contributor on whitelist
        if (IContributorRestrictions(contributorRestrictions).isAllowed(contributor) == false)
            return true;

        // If he already has some qualified contributions, just process the new one
        if (contributionsList[contributor].length > 0) {
            _addContribution(contributor, currency, amount);
            return true;
        }

        // If he never had qualified contributions before, see if he has now passed
        // the minAmountBCY and if so add his buffered contributions to qualified contributions

        // get the value in BCY of his buffered contributions
        uint256 bufferedContributionsBCY = getBufferedContributionsBCY(contributor);

        // if the contributor is still below the minimum, return
        if (bufferedContributionsBCY < minAmountBCY)
            return true;

        // move all the buffered contributions to qualified contributions
        _addBufferedContributions(contributor);

        return true;
    }

    /**
     *  Allows contributor to get refunds of the amounts he contributed, if
     *  various conditions are met
     *
     *  @return true on success
     */
    function getRefund() external returns (bool) {
        require(
            isFinished == true || block.timestamp > endDate.add(expirationTime),
            "Withdrawal failed: fundraise has not finished"
        );
        require(contributionsLocked == false, "Withdrawal failed: contibutions are locked until expiry");

        _refundETHContributions(msg.sender);
        _refundERC20Contributions(msg.sender);
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
    function _refundETHContributions(address contributor) internal returns (bool) {

        uint256 amountWithdrawn;
        for (uint256 i = 0; i < contributionsList[contributor].length; i++) {
            // @TODO add sums and qualifiedContributions handling
            if (contributionsList[contributor][i].currency != address(0))
                continue;
            if (contributionsList[contributor][i].status != ContributionStatus.Refundable)
                continue;
            msg.sender.transfer(contributionsList[contributor][i].amount);
            amountWithdrawn += contributionsList[contributor][i].amount;
            contributionsList[contributor][i].status = ContributionStatus.Refunded;
        }

        delete contributionsList[contributor];

        // withdraw from the buffer too
        uint256 bufferAmount = bufferedContributions[contributor][ETH];
        if (bufferAmount > 0) {
            msg.sender.transfer(bufferAmount);
            amountWithdrawn += bufferAmount;
            bufferedContributions[contributor][ETH] = 0;
        }

        emit ContributorWithdrawal(contributor, ETH, amountWithdrawn);
        return true;
    }

    /**
     *  Helper function for refunding a particular contributor his buffered
     *  ERC20 tokens. This function doesn't handle ETH, nor qualified
     *  contributions
     *
     *  @param contributor the price of individual token, in BCY
     *  @return the amount that was refunded
     */
    function _refundBufferedERC20(address contributor) internal returns (uint256) {
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
            sum += amount;
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
    function _refundERC20Contributions(address contributor) internal returns (bool) {
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

            amount += _refundBufferedERC20(contributor);
            emit ContributorWithdrawal(contributor, currency, amount);
        }

        delete contributionsList[contributor];
        return true;
    }

    /**
     *  Perform all the necessary actions to finish the fundraise
     *
     *  @return true on success
     */
    function _finishFundraise() internal onlyOwner() returns (bool) {
        require(
            isFinished == false,
            "Failed to finish fundraise: already finished"
        );
        require(
            block.timestamp < endDate.add(expirationTime),
            "Failed to finish fundraise: expiration time passed"
        );

        uint256 totalContributionsBCY = getQualifiedSumsBCY();
        require(totalContributionsBCY >= softCapBCY, "Failed to finish: SoftCap not reached");

        // lock the fundraise amount... it will be somewhere between the soft and hard caps
        fundraiseAmountBCY = totalContributionsBCY < hardCapBCY ?
                             totalContributionsBCY : hardCapBCY;

        // Lock the exchange rates between the accepted currencies and BCY
        _lockExchangeRates();

        // find out the token price
        // @TODO include Presale in this
        SRC20tokenPriceBCY = SRC20tokenPriceBCY > 0 ?
                             SRC20tokenPriceBCY : fundraiseAmountBCY / SRC20tokenSupply;

        isFinished = true;
        return true;
    }

    /**
     *  Once a contributor has been Whitelisted, this function gets called to
     *  process his buffered/pending transactions
     *
     *  @param contributor the contributor we want to add
     *  @return true on success
     */
    function acceptContributor(
        address contributor
    )
        external
        ongoing
        onlyContributorRestrictions
        returns (bool)
    {
        _acceptContributor(contributor);
        return true;
    }

    /**
     *  Worker function for acceptContributor()
     *
     *  @param contributor the contributor we want to add
     *  @return true on success
     */
    function _acceptContributor(address contributor) internal returns (bool) {
        // Check whether the contributor is restricted
        require(IContributorRestrictions(contributorRestrictions).isAllowed(contributor));

        // get the value in BCY of his buffered contributions
        uint256 bufferedContributionsBCY = getBufferedContributionsBCY(contributor);

        // if we are still below the minimum, return
        if (bufferedContributionsBCY < minAmountBCY)
            return true;

        // process all the buffers
        _addBufferedContributions(contributor);

        emit ContributorAccepted(contributor);
        return true;
    }

    /**
     *  Removes a contributor (his contributions)
     *  This function can only be called by the Token Issuer (fundraise
     *  contract owner) or by the restrictions/whitelisting contract
     *  See _removeContributor for more information
     *
     *  @param contributor the contributor we want to remove
     *  @return true on success
     */
    function removeContributor(
        address contributor
    )
        external
        ongoing
        onlyContributorRestrictions
        returns (bool)
    {
        _removeContributor(contributor);
        return true;
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
    function _removeContributor(address contributor) internal returns (bool) {
        // make sure he is not on whitelist, if he is he can't be rejected
        require(!IContributorRestrictions(contributorRestrictions).isAllowed(contributor));

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

        // adjust the global sums
        // NOTE: we'll actually leave global sums as they are, as they need to stay the same for historical
        // balances to work

        // get the value in BCY of his qualified contributions (that we shall give back)
        uint256 qualifiedContributionsBCY = getQualifiedContributionsBCY(contributor);

        // adjust the caps, which are always in BCY
        softCapBCY = softCapBCY + qualifiedContributionsBCY;
        hardCapBCY = hardCapBCY + qualifiedContributionsBCY;

        // decrease the global counter of contributors
        numberOfContributors--;

        emit ContributorRemoved(contributor);
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
        address _currency
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
     *  Process a single currency withdrawal by the Issuer, making sure not more
     *  than the correct amount is taken
     *
     *  @param currency the currency of the contributions we want to process
     *  @return true on success
     */
    function _processIssuerWithdrawal(address currency) internal returns (bool) {
        uint256 amount = qualifiedSums[currency];
        uint256 amountBCY = cr.toBCY(qualifiedSums[currency], currency);
        if (totalIssuerWithdrawalsBCY + amountBCY > fundraiseAmountBCY) {
            amount = qualifiedSums[currency] *
                     (fundraiseAmountBCY - totalIssuerWithdrawalsBCY) / amountBCY;
            amountBCY = cr.toBCY(amount, currency);
        }

        qualifiedSums[currency] -= amount;
        totalIssuerWithdrawalsBCY += amountBCY;

        if (currency == ETH)
            issuerWallet.transfer(amount);
        else
            IERC20(currency).transfer(issuerWallet, amount);

        emit IssuerWithdrawal(issuerWallet, currency, amount);
        return true;
    }

    /**
     *  Stake and Mint without using ISOP (IssuerStakeOfferPool)
     *
     *  NOTE: this function assumes that the Token Issuer has acquired SWM by
     *  some other means and put them on the account of the Fundraise contract... it
     *  does not facilitate him using fundraise proceeds to get SWM
     *
     *  @return true on success
     */
    function stakeAndMint() public returns (bool) {

        uint256 numSRC20Tokens = SRC20tokenSupply > 0 ?
                                 SRC20tokenSupply : fundraiseAmountBCY / SRC20tokenPriceBCY;
        IGetRateMinter(minter).stakeAndMint(src20, numSRC20Tokens);

        _finishFundraise();

        // Withdraw (to the issuer) the ETH and the Tokens
        _withdrawRaisedFunds();

        return true;
    }

    /**
     *  Stake and Mint using ISOP, letting ISOP parse providers
     *
     *  @param ISOP address of an ISOP contract
     *  @param maxMarkup maximum markup the caller is willing to accept
     *  @return true on success
     */
    function stakeAndMint(address ISOP, uint256 maxMarkup) external returns (bool) {
        // we just create an empty list and call the worker function with that
        address[] memory a;
        stakeAndMint(ISOP, a, maxMarkup);
        return true;
    }

    /**
     *  Stake and Mint using ISOP to get SWM from specific providers
     *
     *  @param ISOP address of an ISOP contract
     *  @param addressList an array of addresses representing SWM providers
     *  @param maxMarkup maximum markup the caller is willing to accept
     *  @return true on success
     */
    function stakeAndMint(
        address ISOP,
        address[] memory addressList,
        uint256 maxMarkup
    )
        public
        returns (bool)
    {
        // This has all the conditions and will blow up if they are not met
        // @TODO move below stakeAndMint
        _finishFundraise();
        // @TODO investigate: IIssuerStakeOfferPool(ISOP).stakeAndMint(addressList, maxMarkup, swmAmount, ...)
        // @TODO Update the NAV, but this contract is not allowed to do it...
        // assetRegistry.updateNetAssetValueUSD(src20, netAssetValueUSD);
        uint256 netAssetValueUSD = cr.toUSDC(fundraiseAmountBCY, cr.getBaseCurrency());
        uint256 swmAmount = IGetRateMinter(minter).calcStake(netAssetValueUSD);

        uint256 spentETH;
        uint256 priceETH;
        if (addressList.length == 0) { // we want ISOP to determine providers
            priceETH = IIssuerStakeOfferPool(ISOP).loopGetSWMPriceETH(swmAmount, maxMarkup);
            IIssuerStakeOfferPool(ISOP).loopBuySWMTokens.value(priceETH)(swmAmount, maxMarkup);
            // @TODO accept all currencies
        }
        else { // loop through the list we got
           for (uint256 i = 0; i < addressList.length; i++) {
                 address swmProvider = addressList[i];

                // calculate the number of tokens to get from this provider
                uint256 tokens = swmAmount > IIssuerStakeOfferPool(ISOP).getTokens(swmProvider) ?
                                 IIssuerStakeOfferPool(ISOP).getTokens(swmProvider) : swmAmount;

                // send ETH and get the tokens
                priceETH = IIssuerStakeOfferPool(ISOP).getSWMPriceETH(swmProvider, tokens);
                IIssuerStakeOfferPool(ISOP).buySWMTokens.value(priceETH)(swmProvider, tokens);

                // reduce the number we still need to get by the amount we just got
                swmAmount -= tokens;
                // increase the counter of ETH we spent
                spentETH += priceETH;
           }
        }

        // decrease the global ETH balance
        qualifiedSums[ETH] -= spentETH;

        uint256 numSRC20Tokens = SRC20tokenSupply > 0 ?
                                 SRC20tokenSupply : fundraiseAmountBCY / SRC20tokenPriceBCY;
        // Stake and mint
        IGetRateMinter(minter).stakeAndMint(src20, numSRC20Tokens);

        // Withdraw (to the issuer) the ETH and the Tokens
        _withdrawRaisedFunds();

        return true;
    }

    /**
     *  Allow the caller, if he is eligible, to withdraw his SRC20 tokens once
     *  they have been minted
     *
     *  @return true on success
     */
    function claimTokens() external returns (uint256) {
        // @TODO make this function restartable and return how many tokens are left to claim
        require(isFinished, "Cannot claim tokens: fundraise has not finished!");

        // go through a contributor's contributions, sum up those qualified for
        // converting into tokens
        uint256 totalContributorAcceptedBCY = 0;
        for (uint256 i = 0; i<contributionsList[msg.sender].length; i++) {
            // to make sure we pay him out only once
            if (contributionsList[msg.sender][i].status != ContributionStatus.Refundable)
                continue;

            // we change to accepted... but could also be deleting
            contributionsList[msg.sender][i].status = ContributionStatus.Accepted;

            uint256 contributionBCY = cr.toBCY(
                contributionsList[msg.sender][i].amount,
                contributionsList[msg.sender][i].currency
            );

            uint256 historicalBalanceBCY = getHistoricalBalanceBCY(contributionsList[msg.sender][i].sequence);
            // Whether we take the whole amount...
            if(historicalBalanceBCY + contributionBCY < fundraiseAmountBCY) {
                totalContributorAcceptedBCY += contributionBCY;
            }
            else { // ...or just a part of it
                totalContributorAcceptedBCY += fundraiseAmountBCY - historicalBalanceBCY;
                uint256 refund = historicalBalanceBCY + contributionBCY - fundraiseAmountBCY;
                bufferedContributions[msg.sender][contributionsList[msg.sender][i].currency] += refund;
                break; // we've hit the end, break from the loop
            }
        }

        uint256 tokenAllotment = totalContributorAcceptedBCY / SRC20tokenPriceBCY;
        ISRC20(src20).transfer(msg.sender, tokenAllotment);
        emit SRC20TokensClaimed(msg.sender, tokenAllotment);
        return 0;
    }

}
