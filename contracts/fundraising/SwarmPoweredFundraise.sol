pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IGetRateMinter.sol";
import "../interfaces/IAffiliateManager.sol";
import "../interfaces/ICurrencyRegistry.sol";
import "../interfaces/IIssuerStakeOfferPool.sol";
import "../interfaces/IContributorRestrictions.sol";

import "../fundraising/Utils.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract SwarmPoweredFundraise {

    using SafeMath for uint256;

    event ContributionReceived(address indexed from, uint256 amount, uint256 sequence, address baseCurrency);
    event ContributorAccepted(address contributor);

    // Setup variables that never change
    address internal ETH = address(0);
    address private owner;
    string public label;

    // @TODO Some parameters can be moved to separate contract either extendie 
    // or total separation e.g. fundraisingConfiguration
    uint256 public startDate;
    uint256 public endDate;
    uint256 public minAmountBCY;
    uint256 public maxAmountBCY;
    uint256 public expirationTime = 7776000; // default: 60 * 60 * 24 * 90 = ~3months
    // variables that can change over time
    uint256 internal sequence;
    uint256 public softCapBCY;
    uint256 public hardCapBCY;
    uint256 public SRC20tokenPriceBCY;
    uint256 public SRC20tokensToMint;
    uint256 public fundraiseAmountBCY;
    uint256 public numberOfContributors;
    uint256 public totalIssuerWithdrawalsBCY;

    address public src20;
    address public minter;
    address payable issuerWallet;
    address public affiliateManager;
    address public contributorRestrictions;
    address[] internal acceptedCurrencies;
    address public currencyRegistry;
    ICurrencyRegistry internal cr;

    bool public isFinished; // default == false;
    bool public setupCompleted; // default == false
    bool public offchainContributionsAllowed; // default == false;
    bool public contributionsLocked = true;

    // per contributor, iterable list of his contributions, where each contribution
    // holds information about its position in the global queue of contributions
    mapping(address => Utils.Contribution[]) contributionsList;

    // per contributor and currency, pending amount
    mapping(address => mapping(address => uint256)) public bufferedContributions;

    // per contributor and currency, qualified amount
    // a qualified amount is amount that has passed min/max checks and has been placed in the queue
    mapping(address => mapping(address => uint256)) public qualifiedContributions;

    // per currency, total qualified sums
    mapping(address => uint256) public qualifiedSums;

    // per currency, total buffered sums
    mapping(address => uint256) public bufferedSums;

    // per currency, an array of historical balances
    mapping(address => Utils.Balance[]) historicalBalance;

    /**
     * Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner!");
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
        _ongoing();
        _;
    }

    // forced by bytecode limitations, kept just below the modifier for clarity
    function _ongoing() internal view returns (bool) {
        require(setupCompleted, "Fundraise setup not completed!");
        require(isFinished == false, "Fundraise has finished!");
        require(block.timestamp >= startDate, "Fundraise has not started yet!");
        require(block.timestamp <= endDate, "Fundraise has ended");
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
        uint256 _SRC20tokensToMint,
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
        SRC20tokensToMint = _SRC20tokensToMint;
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
        uint256 _maxAmountBCY,
        address _affiliateManager,
        address _contributorRestrictions,
        bool _contributionsLocked
    )
    external
    onlyOwner()
    {
        minAmountBCY = _minAmountBCY;
        maxAmountBCY = _maxAmountBCY;
        affiliateManager = _affiliateManager;
        contributorRestrictions = _contributorRestrictions;
        contributionsLocked = _contributionsLocked;
        setupCompleted = true;
    }

    /**
     *  Cancel the fundraise. Can be done by the Token Issuer at any time
     *  The contributions are then available to be withdrawn by contributors
     *
     *  @return true on success
     */
    function cancelFundraise() external onlyOwner() returns (bool) {
        isFinished = true;
        return true;
    }

    /**
     *  Loop through currencies and get the value (in BCY) of all the
     *  contributor's contributions, either qualified or buffered
     *  @param contributor the address of the contributor
     *  @param qualified whether to add up the qualified or the buffered
     *  @return sum of all buffered contributions for the contributor,
     *          converted to BCY
     */
    function getContributionsBCY(address contributor, bool qualified) public returns (uint256) {
        uint256 sum;
        for (uint256 i = 0; i < acceptedCurrencies.length; i++) {
            address currency = acceptedCurrencies[i];
            sum = sum.add(
                cr.toBCY(
                    qualified == true ? 
                        qualifiedContributions[contributor][currency] :
                        bufferedContributions[contributor][currency], 
                    currency
                )
            );
        }
        return sum;
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
        require(offchainContributionsAllowed, "Not allowed by setup!");

        // whitelist the contributor
        IContributorRestrictions(contributorRestrictions).whitelistAccount(contributor);

        // we've just whitelisted him but still need to check
        // for example it could be that max number of contributors has been exceeded
        IContributorRestrictions(contributorRestrictions).checkRestrictions(contributor);

        // add the contribution to the buffer
        bufferedContributions[contributor][currency] = bufferedContributions[contributor][currency]
            .add(amount);

        // add the contribution to the queue and then subtract from buffered
        // because any extra amount will have been added there by the function,
        // but the extra amount must never be refundable
        bufferedContributions[contributor][currency] = bufferedContributions[contributor][currency]
            .sub(_addContribution(contributor, currency, amount));

        // set up the contribution we have just added so that it can not be withdrawn
        contributionsList[contributor][contributionsList[contributor].length.sub(1)]
                         .status = Utils.ContributionStatus.Offchain;

        return true;
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
        require(amount > 0, "Amount has to be positive!");
        require(
            IERC20(erc20).transferFrom(msg.sender, address(this), amount),
            "ERC20 transfer failed!"
        );

        _contribute(msg.sender, erc20, amount, affiliateLink);
        return true;
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
        onlyAcceptedCurrencies(currency)
        returns (bool)
    {
        if (bytes(affiliateLink).length > 0) {
            // send the reward to referee's buffer
            (address affiliate, uint256 percentage) =
                IAffiliateManager(affiliateManager).getAffiliate(affiliateLink);
            bufferedContributions[affiliate][currency] = bufferedContributions[affiliate][currency]
                .add(amount.mul(percentage));
            // adjust the amount
            amount = amount.sub(amount.mul(percentage));
        }

        // add the contribution to the buffer
        bufferedContributions[contributor][currency] = bufferedContributions[contributor][currency]
            .add(amount);
        bufferedSums[currency] = bufferedSums[currency].add(amount);

        // Check whether contributor is prevented from contributing
        IContributorRestrictions(contributorRestrictions).checkRestrictions(contributor);

        // If he already has some qualified contributions, just process the new one
        // hmm is this the case??? whitelist/graylist?
        if (contributionsList[contributor].length > 0) {
            _addContribution(contributor, currency, amount);
            return true;
        }

        // If he never had qualified contributions before, see if he has now passed
        // the minAmountBCY and if so add his buffered contributions to qualified contributions
        // get the value in BCY of his buffered contributions
        uint256 bufferedContributionsBCY = getContributionsBCY(contributor, false);

        // if the contributor is still below the minimum, return
        // what is the point of this return?
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
            isFinished == true ||
            block.timestamp > endDate.add(expirationTime) ||
            contributionsLocked == false,
            "Fundraise has not finished!"
        );

        Utils.getRefund(
            msg.sender,
            acceptedCurrencies,
            contributionsList,
            qualifiedContributions,
            bufferedContributions,
            qualifiedSums,
            bufferedSums
        );

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
        // get the value in BCY of his buffered contributions
        uint256 bufferedContributionsBCY = getContributionsBCY(contributor, false);

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
        Utils.removeContributor(
            contributor,
            contributionsList,
            bufferedContributions,
            qualifiedContributions
        );
        // decrease the global counter of contributors
        numberOfContributors = numberOfContributors.sub(1);

        // get the value in BCY of his qualified contributions (that we shall give back)
        uint256 qualifiedContributionsBCY = getContributionsBCY(contributor, true);

        // adjust the caps, which are always in BCY
        softCapBCY = softCapBCY.add(qualifiedContributionsBCY);
        hardCapBCY = hardCapBCY.add(qualifiedContributionsBCY);

        return true;
    }

    /**
     *  Stake and Mint using ISOP to get SWM from specific providers
     *  If ISOP parameter is address(0), SWM has to be on the fundraise contract
     *
     *  @param ISOP address of an ISOP contract
     *  @param maxMarkup maximum markup the caller is willing to accept
     *  @return true on success
     */
    function stakeAndMint(
        address ISOP,
        uint256 maxMarkup
    )
        public
        onlyOwner()
        returns (bool)
    {
        // This has all the conditions and will blow up if they are not met
        uint256 numSRC20Tokens = _finishFundraise();
        
        if(ISOP == address(0)) {
            IGetRateMinter(minter).stakeAndMint(src20, numSRC20Tokens);
            // Withdraw (to the issuer) the ETH and the Tokens
            _withdrawRaisedFunds();
            return true;
        }
        
        // @TODO investigate: IIssuerStakeOfferPool(ISOP).stakeAndMint(addressList, maxMarkup, swmAmount, ...)
        // @TODO Update the NAV, but this contract is not allowed to do it...
        // assetRegistry.updateNetAssetValueUSD(src20, netAssetValueUSD);
        uint256 netAssetValueUSD = cr.toUSDC(fundraiseAmountBCY, cr.getBaseCurrency());
        uint256 swmAmount = IGetRateMinter(minter).calcStake(netAssetValueUSD);

        uint256 spentETH;
        uint256 priceETH;

        // we want ISOP to determine providers
        priceETH = IIssuerStakeOfferPool(ISOP).loopGetSWMPriceETH(swmAmount, maxMarkup);
        IIssuerStakeOfferPool(ISOP).loopBuySWMTokens.value(priceETH)(swmAmount, maxMarkup);
        // NOTE: one day, rework to accept all currencies, not just ETH

        // decrease the global ETH balance
        qualifiedSums[ETH] = qualifiedSums[ETH].sub(spentETH);

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

        require(isFinished, "Fundraise has not finished!");

        Utils.claimTokens(
            src20,
            currencyRegistry,
            SRC20tokenPriceBCY,
            fundraiseAmountBCY,
            acceptedCurrencies,
            contributionsList,
            historicalBalance,
            bufferedContributions
        );

        return 0;
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
            if(bufferedContributions[contributor][currency] == 0)
                continue;
            sum = sum.add(_addContribution(contributor, currency, bufferedContributions[contributor][currency]));
        }
        return sum;
    }

    /**
     *  Worker function that adds a contribution to the list of contributions
     *  and updates all the relevant sums and balances
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
        returns (uint256)
    {
        // convert the coming contribution to BCY
        uint256 amountBCY = cr.toBCY(amount, currency);

        // get the value in BCY of his previous qualified contributions
        uint256 previousContributionsBCY = getContributionsBCY(contributor, true);

        // if we are above with previous amount, due to exchange rate fluctuations, return
        if (previousContributionsBCY >= maxAmountBCY)
            return amount;

        // get the total with this contribution
        uint256 contributionsBCY = previousContributionsBCY.add(amountBCY);

        // if we'd cross the maxAmount, take only the portion of the contribution up to the max
        // we use percentage because we need to cut contribution currency, not BCY
        uint256 qualifiedAmount = amount;
        if (contributionsBCY > maxAmountBCY)
            qualifiedAmount = amount.mul(maxAmountBCY.sub(previousContributionsBCY)).div(amountBCY);

        // get what we are going to take and leave any extra in the buffer
        bufferedContributions[contributor][currency] = bufferedContributions[contributor][currency]
            .sub(qualifiedAmount);
        bufferedSums[currency] = bufferedSums[currency].sub(qualifiedAmount);

        // if this is the first time he's contributing, increase the contributor counter
        if (contributionsList[contributor].length == 0)
            numberOfContributors = numberOfContributors.add(1);

        Utils.Contribution memory c;
        sequence = sequence.add(1);
        c.currency = currency;
        c.amount = qualifiedAmount;
        c.sequence = sequence;
        c.status = Utils.ContributionStatus.Refundable;
        contributionsList[contributor].push(c);

        // adjust the global and historical sums
        qualifiedContributions[contributor][currency] = qualifiedContributions[contributor][currency]
            .add(qualifiedAmount);
        qualifiedSums[currency] = qualifiedSums[currency].add(qualifiedAmount);
        Utils.Balance memory balance;
        balance.sequence = sequence;
        balance.balance = qualifiedSums[currency];
        historicalBalance[currency].push(balance);

        emit ContributionReceived(contributor, qualifiedAmount, sequence, currency);
        return qualifiedAmount.sub(amount);
    }

    /**
     *  Perform all the necessary actions to finish the fundraise
     *
     *  @return true on success
     */
    function _finishFundraise() internal onlyOwner() returns (uint256) {
        require(isFinished == false, "Already finished!");
        require(block.timestamp < endDate.add(expirationTime), "Expiration time passed!");
        uint256 totalContributionsBCY = Utils.getQualifiedSumsBCY(
            currencyRegistry,
            acceptedCurrencies,
            qualifiedSums
        );
        require(totalContributionsBCY >= softCapBCY, "SoftCap not reached!");

        // lock the fundraise amount... it will be somewhere between the soft and hard caps
        fundraiseAmountBCY = totalContributionsBCY < hardCapBCY ?
                             totalContributionsBCY : hardCapBCY;

        // Lock the exchange rates between the accepted currencies and BCY
        // so that claimTokens() calculates correctly whenever called
        cr.lockExchangeRates();

        // find out the token price
        SRC20tokenPriceBCY = SRC20tokenPriceBCY > 0 ?
                             SRC20tokenPriceBCY : fundraiseAmountBCY.div(SRC20tokensToMint);

        isFinished = true;

        return(
            SRC20tokensToMint > 0 ?
            SRC20tokensToMint : fundraiseAmountBCY.div(SRC20tokenPriceBCY)
        );
    }

    /**
     *  Loop through the accepted currencies and initiate a withdrawal for
     *  each currency, sending the funds to the Token Issuer
     *
     *  @return true on success
     */
    function _withdrawRaisedFunds() internal returns (bool) {

        for (uint256 i = 0; i < acceptedCurrencies.length; i++)
            totalIssuerWithdrawalsBCY = Utils.processIssuerWithdrawal(
                issuerWallet,
                acceptedCurrencies[i],
                currencyRegistry,
                totalIssuerWithdrawalsBCY,
                fundraiseAmountBCY,
                qualifiedSums
            );

        return true;
    }

}
