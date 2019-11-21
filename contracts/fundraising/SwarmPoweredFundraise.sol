pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

import "../interfaces/IIssuerStakeOfferPool.sol";
import "../interfaces/IGetRateMinter.sol";
import "../interfaces/IUniswap.sol";
import "../interfaces/IContributionRules.sol";
import "../interfaces/IContributorRestrictions.sol";
import "../interfaces/ISRC20.sol";

/**
 * @title The Fundraise Contract
 * This contract allows the deployer to perform a Swarm-Powered Fundraise.
 */
contract SwarmPoweredFundraise is Ownable {

    using SafeMath for uint256;
    // @TODO convert all math in the contract to SafeMath once happy with logic

    event Contribution(address indexed from, uint256 amount, uint256 sequence, address baseCurrency);
    event SRC20TokensClaimed(address indexed by, uint256 tokenAllotment);
    event ContributorWithdrawal(address contributorWallet, address currency, uint256 amount);
    event IssuerWithdrawal(address issuerWallet, address currency, uint256 amount);
    event ContributorRemoved(address contributor);
    event ContributorAccepted(address contributor);

    // Setup variables that never change
    string public label;

    uint256 public startDate;
    uint256 public endDate;
    address public baseCurrency;
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

    address public src20;
    address public contributionRules;
    address public contributorRestrictions;
    address public SwarmERC20;
    address public minter;
    address payable issuerWallet;

    bool public isFinished;
    bool public contributionLocking = true;
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

    // @TODO pass these as parameters
    // @TODO keep contracts in a mapping and currencies as an array/enum
    // mapping(uint256 => address) erc20;
    address zeroAddr = address(0); // 0x0000000000000000000000000000000000000000; // Stands for ETH
    address erc20DAI = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address erc20USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address erc20WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    // IAccCurrency - address accCurrency;

    // @TODO abstract away conversions and exchanges to an interface
    // NOTE: bonding curves are not the same as deep markets where any amount barely moves the price
    // A register of one Uniswap exchange per each currency
    mapping(address => address) exchange;

    // State variables that change over time
    enum ContributionStatus { Refundable, Refunded, Accepted, Offchain }

    struct contribution {
        address currency;
        uint256 amount;
        uint256 sequence; // @TODO rething the name, maybe queuePosition
        ContributionStatus status;
    }

    // @TODO maybe rename to contributionsQueue?
    // per contributor, iterable list of his contributions
    mapping(address => contribution[]) contributionsList; 

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

    // @TODO maybe combine some of the per-currency stats like this
    struct CurrencyStats {
        address exchangeContract;
        uint256 finalExchangeRate;
        uint256 totalBufferedAmount;
        uint256 totalQualifiedAmount;
    }
    mapping(address => CurrencyStats) currencyStats;

    struct bal {
        uint256 sequence;
        uint256 balance;
    }
    mapping(address => bal[]) historicalBalance;

    // uint256 rateETHtoBCY;
    // uint256 rateDAItoBCY;
    // uint256 rateUSDCtoBCY;
    // uint256 rateWBTCtoBCY;

    // only allow the external contract that handles restrictions to call
    modifier onlyContributorRestrictions() {
        require(msg.sender == contributorRestrictions);
        _;
    }

    // only allow the currencies we accept
    modifier onlyAcceptedCurrencies(address erc20) {
        require(erc20 == zeroAddr ||
                erc20 == erc20DAI ||
                erc20 == erc20USDC ||
                erc20 == erc20WBTC, 
                'Unsupported currency');
        _;
    }

    // only allow if the fundraise has started and is ongoing 
    modifier ongoing() {
        require(SRC20tokenPriceBCY != 0 || SRC20tokenSupply != 0, "Token price or supply are not set");
        require(setupCompleted, 'Fundraise setup not completed!');
        require(isFinished == false, 'Fundraise has finished!');
        require(block.timestamp >= startDate, "Fundraise did not start yet!");
        require(block.timestamp <= endDate, "Fundraise has ended");
        _;
    }

    constructor(
        string memory _label,
        address _src20,
        uint256 _SRC20tokenSupply,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _softCapBCY,
        uint256 _hardCapBCY,
        address _baseCurrency
    ) public {
        label = _label;
        src20 = _src20;
        SRC20tokenSupply = _SRC20tokenSupply;
        startDate = _startDate;
        endDate = _endDate;
        softCapBCY = _softCapBCY;
        hardCapBCY = _hardCapBCY;

        require(_baseCurrency == erc20DAI ||
                _baseCurrency == erc20USDC ||
                _baseCurrency == erc20WBTC ||
                _baseCurrency == zeroAddr, 'Unsupported base currency');

        baseCurrency = _baseCurrency;

        // @TODO parametrize this
        exchange[erc20DAI] = 0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14;
        exchange[erc20USDC] = 0x97deC872013f6B5fB443861090ad931542878126;
        exchange[erc20WBTC] = 0x4d2f5cFbA55AE412221182D8475bC85799A5644b;
    }

    // This gets used if a person simply sends ETH to the contract
    function() external payable {

        // We want the Token Issuer to be able to send ETH to the contract even after
        // the fundraise has finished. He might need to get SWM via ISOP
        require(isFinished == false || msg.sender == owner());

        _contribute(msg.sender, zeroAddr, msg.value, '');
    }

    // This could all be in the constructor, but we have to avoid stack too deep error
    function setupContract(
        uint256 _minAmountBCY,
        uint256 _maxAmountBCY
    ) external onlyOwner returns (bool) {
        minAmountBCY = _minAmountBCY;
        maxAmountBCY = _maxAmountBCY;
        // @TODO make sure we can't run without setup
        // bool isStarted = true;
    }

    // We can either set the token price, or the total token supply
    function setSRC20tokenPriceBCY(uint256 _SRC20tokenPriceBCY) external returns (bool) {
        // One has to be set or the other, never both.
        require(SRC20tokenPriceBCY == 0, "Token price already set");
        require(SRC20tokenSupply == 0, "Total token amount already set");

        SRC20tokenPriceBCY = _SRC20tokenPriceBCY;
        return true;
    }

    // We can either set the token total supply, or the token price
    function setSRC20tokenSupply(uint256 _SRC20tokenSupply) external returns (bool) {
        require(SRC20tokenPriceBCY == 0, "Token price already set");
        require(SRC20tokenSupply == 0, "Total token amount already set");

        SRC20tokenSupply = _SRC20tokenSupply;
        return true;
    }

    // Loop through accepted currencies and get the value (in BCY) of contributor's 
    // buffered contributions
    function getBufferedContributionsBCY (address contributor) public returns (uint256) {
        return toBCY( bufferedContributions[contributor][zeroAddr], zeroAddr) +
               toBCY( bufferedContributions[contributor][erc20DAI], erc20DAI) +
               toBCY( bufferedContributions[contributor][erc20USDC], erc20USDC) +
               toBCY( bufferedContributions[contributor][erc20WBTC], erc20WBTC);   
    }

    // Loop through accepted currencies and get the value (in BCY) of contributor's 
    // qualified contributions
    function getQualifiedContributionsBCY(address contributor) public returns (uint256) {
        return toBCY( qualifiedContributions[contributor][zeroAddr], zeroAddr) +
               toBCY( qualifiedContributions[contributor][erc20DAI], erc20DAI) +
               toBCY( qualifiedContributions[contributor][erc20USDC], erc20USDC) +
               toBCY( qualifiedContributions[contributor][erc20WBTC], erc20WBTC);
    }

    // Loop through the accepted currencies and return the sum of historical 
    // balances at the time of the _sequence, converted to base currency
    function getHistoricalBalanceBCY(uint256 _sequence) public returns (uint256) {
        return toBCY( getHistoricalBalance(_sequence, zeroAddr), zeroAddr) + 
               toBCY( getHistoricalBalance(_sequence, erc20DAI), erc20DAI) + 
               toBCY( getHistoricalBalance(_sequence, erc20USDC), erc20USDC) + 
               toBCY( getHistoricalBalance(_sequence, erc20WBTC), erc20WBTC);
    }

    // Loop through the accepted currencies and lock the exchange rates 
    // between them and BCY
    function _lockExchangeRates() internal returns (bool) {
        // @TODO check with business if this logic is acceptable
        lockedExchangeRate[zeroAddr] = toBCY( 1, zeroAddr );
        lockedExchangeRate[erc20DAI] = toBCY( 1, erc20DAI );
        lockedExchangeRate[erc20USDC] = toBCY( 1, erc20USDC );
        lockedExchangeRate[erc20WBTC] = toBCY( 1, erc20WBTC );
    }

    // @TODO for the processing of buffers we can't have min/max checking in this function
    // because we step by step accept small amounts
    // maybe have another more basic function 
    // addContributionMinMax, addContribution
    function _addContribution(address contributor, address erc20, uint256 amount) 
                              internal onlyAcceptedCurrencies(erc20) returns (uint256) {

        // convert the coming contribution to BCY
        uint256 amountBCY = toBCY( amount, erc20 );

        // get the value in BCY of his previous qualified contributions
        uint256 previousContributionsBCY = getQualifiedContributionsBCY(contributor);

        // get the total with this contribution
        uint256 contributionsBCY = previousContributionsBCY + amountBCY;

        // if we are still below the minimum, return
        //if (contributionsBCY < minAmountBCY)
        //    return;

        // now do the max checking... 

        // if we are above with previous amount, due to exchange rate fluctuations, return
        if (previousContributionsBCY >= maxAmountBCY)
            return 0;

        uint256 qualifiedAmount;
        // if we cross the max, take only a portion of the contribution, via a percentage
        if (contributionsBCY > maxAmountBCY) {
            qualifiedAmount = (maxAmountBCY - previousContributionsBCY) / amountBCY
                            * amount;
        }
        else
            qualifiedAmount = amount;

        // leave the extra in the buffer, get the all the rest
        bufferedContributions[contributor][erc20] -= qualifiedAmount;

        // if this is the first time he's contributing, increase the contributor counter
        if (contributionsList[contributor].length == 0)
            numberOfContributors++;

        contribution memory c;
        sequence++;
        c.currency = erc20;
        c.amount = qualifiedAmount;
        c.sequence = sequence;
        c.status = ContributionStatus.Refundable;
        contributionsList[contributor].push(c);

        // adjust the global and historical sums
        qualifiedContributions[contributor][erc20] += qualifiedAmount;
        qualifiedSums[erc20] += qualifiedAmount;
        bal memory balance;
        balance.sequence = sequence;
        balance.balance = qualifiedSums[erc20];
        historicalBalance[erc20].push(balance);

        emit Contribution(contributor, qualifiedAmount, sequence, erc20);
        return qualifiedAmount - amount;
    }

    // Allows Token Issuer to add a contribution to the fundraise contract's accounting
    // in the case he received an offchain contribution, for example
    function addOffchainContribution(address contributor, address erc20, uint256 amount) 
             public ongoing() onlyAcceptedCurrencies(erc20) returns (bool) {

        require(offchainContributionsAllowed, 'Offchain contribution failed: not allowed by setup!');

        // whitelist the contributor
        IContributorRestrictions(contributorRestrictions).whitelistAccount(contributor);

        // we've just whitelisted him but still need to check
        // for example it could be that max number of contributors has been exceeded
        IContributorRestrictions(contributorRestrictions).isAllowed(contributor);

        // add the contribution to the buffer
        bufferedContributions[contributor][erc20] += amount;

        // add the contribution to the queue
        uint256 overMax = _addContribution(contributor, erc20, amount);
        // the extra amount must never be refundable
        bufferedContributions[contributor][erc20] -= overMax;

        // set up the contribution we have just added so that it can not be withdrawn
        contributionsList[contributor][contributionsList[contributor].length - 1]
                         .status = ContributionStatus.Offchain;
    }

    // contribute without an affiliate link
    function contribute(address erc20, uint256 amount) 
        public ongoing() onlyAcceptedCurrencies(erc20) returns (bool) {
        _contribute(msg.sender, erc20, amount, "");
    }

    // contribute with an affiliate link
    function contribute(address erc20, uint256 amount, string memory affiliateLink) 
        public ongoing() onlyAcceptedCurrencies(erc20) returns (bool) {

        require(IERC20(erc20).transferFrom(msg.sender, address(this), amount), 
                'Contribution failed: ERC20 transfer failed!');

        _contribute(msg.sender, erc20, amount, affiliateLink);
    }

    // Worker function for both ETH and ERC20 contributions
    function _contribute(address contributor, address erc20, uint256 amount, string memory affiliateLink) 
        internal returns (bool) {

        if (bytes(affiliateLink).length > 0) {
            //send the reward to referee's buffer
            bufferedContributions[affiliates[affiliateLink].account][erc20] += 
                amount * affiliates[affiliateLink].percentage;

            //adjust the amount
            amount -= amount * affiliates[affiliateLink].percentage;
        }

        // add the contribution to the buffer
        bufferedContributions[contributor][erc20] += amount;

        // Check if contributor on whitelist
        if (IContributorRestrictions(contributorRestrictions).isAllowed(contributor) == false)
            return true;

        // If he already has some qualified contributions, just process the new one
        if (contributionsList[contributor].length > 0) {
            _addContribution(contributor, erc20, amount);
            return true;
        }

        // If he never had qualified contributions before, see if he now has passed the minAmountBCY
        // And if so add his buffered contributions to qualified contributions

        // get the value in BCY of his buffered contributions
        uint256 bufferedContributionsBCY = getBufferedContributionsBCY(contributor);

        // if the contributor is still below the minimum, return
        if (bufferedContributionsBCY < minAmountBCY)
            return true;

        // process all the buffers
        _addContribution(contributor, zeroAddr, bufferedContributions[contributor][zeroAddr]);
        _addContribution(contributor, erc20DAI, bufferedContributions[contributor][erc20DAI]);
        _addContribution(contributor, erc20USDC, bufferedContributions[contributor][erc20USDC]);
        _addContribution(contributor, erc20WBTC, bufferedContributions[contributor][erc20WBTC]);

        return true;
    } // fn

    // Allows Contributor to withdraw all his ETH, if this is permitted by the state of the Fundraise
    function refundContributionETH() external returns (bool) {
        // @TODO contributionLock
        require(isFinished == true && block.timestamp < endDate.add(expirationTime), 'Withdrawal failed: fundraise has not finished');

        uint256 amountWithdrawn;
        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            if (contributionsList[msg.sender][i].currency != address(0))
                continue;
            if (contributionsList[msg.sender][i].status != ContributionStatus.Refundable)
                continue; 
            msg.sender.transfer(contributionsList[msg.sender][i].amount);
            amountWithdrawn += contributionsList[msg.sender][i].amount;
            contributionsList[msg.sender][i].status = ContributionStatus.Refunded;
        }

        delete contributionsList[msg.sender];

        // withdraw from the buffer too
        uint256 bufferAmount = bufferedContributions[msg.sender][zeroAddr];
        if (bufferAmount > 0) {
            msg.sender.transfer(bufferAmount);
            amountWithdrawn += bufferAmount;
            bufferedContributions[msg.sender][zeroAddr] = 0;
        }

        emit ContributorWithdrawal(msg.sender, zeroAddr, amountWithdrawn);
        return true;
    }

    // Worker function for refunding a particular contributor his buffered tokens
    function _refundBuffered(address contributor, address erc20) internal returns (uint256) {
        uint256 amount = bufferedContributions[contributor][erc20];

        if (amount == 0)
            return 0;

        require(IERC20(erc20).transferFrom(address(this), contributor, amount),'ERC20 transfer failed!');
        bufferedContributions[contributor][erc20] = 0;
        return amount;
    }

    // Allows contributor to withdraw all his ERC20 tokens, if this is permitted by the state of the Fundraise
    // Only allow withdrawing of the contributions that are not: Refunded, Accepted, Offchain, or
    // Are still buffered/pending
    function refundContributionToken() external returns (bool) {
        require(isFinished == true && block.timestamp < endDate.add(expirationTime), 
                'Withdrawal failed: fundraise has not finished');
 
        uint256 amountWithdrawnDAI;
        uint256 amountWithdrawnUSDC;
        uint256 amountWithdrawnWBTC;
 
        // We must use a loop instead of just looking at qualifiedContributions because 
        // some contributions could have been offchain and those must not be withdrawable
        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            uint256 amount = contributionsList[msg.sender][i].amount;
            address currency = contributionsList[msg.sender][i].currency;
            ContributionStatus status = contributionsList[msg.sender][i].status;
            
            if (currency == address(0) || status != ContributionStatus.Refundable)
                continue;

            require(IERC20(currency).transferFrom(address(this), msg.sender, amount),
                    'ERC20 transfer failed!');

            contributionsList[msg.sender][i].status = ContributionStatus.Refunded;
            qualifiedContributions[msg.sender][currency] = 0;

            if (currency == erc20DAI) amountWithdrawnDAI += amount;
            if (currency == erc20USDC) amountWithdrawnUSDC += amount;
            if (currency == erc20WBTC) amountWithdrawnWBTC += amount;
        }

        delete contributionsList[msg.sender];

        // withdraw from the buffers too
        amountWithdrawnDAI += _refundBuffered(msg.sender, erc20DAI);
        amountWithdrawnUSDC += _refundBuffered(msg.sender, erc20USDC);
        amountWithdrawnWBTC += _refundBuffered(msg.sender, erc20WBTC);

        emit ContributorWithdrawal(msg.sender, erc20DAI, amountWithdrawnDAI);
        emit ContributorWithdrawal(msg.sender, erc20USDC, amountWithdrawnUSDC);
        emit ContributorWithdrawal(msg.sender, erc20WBTC, amountWithdrawnWBTC);

        return true;
    }

    // This will be called if/when the fundraise expires
    function allowContributionWithdrawals() external returns (bool) {
        delete contributionLocking;
        return true;
    }

    // Retrieve the presale amount and price
    function getPresale() external view returns (uint256, uint256) {
        return (preSaleAmountBCY, preSaleTokensReserved);
    }

    // Perform all the necessary actions to finish the fundraise
    function finishFundraise() internal 
        onlyOwner()
        returns (bool) {

        require(isFinished == false, "Failed to finish fundraise: already finished");

        require(block.timestamp < endDate.add(expirationTime), "Failed to finish fundraise: expiration time passed");

        uint256 totalContributionsBCY = toBCY(qualifiedSums[zeroAddr], zeroAddr) +
                                        toBCY(qualifiedSums[erc20DAI], erc20DAI) +
                                        toBCY(qualifiedSums[erc20USDC], erc20USDC) +
                                        toBCY(qualifiedSums[erc20WBTC], erc20WBTC);

        require(totalContributionsBCY >= softCapBCY, "Failed to finish: SoftCap not reached");

        // lock the fundraise amount... it will be somewhere between the soft and hard caps
        fundraiseAmountBCY = totalContributionsBCY < hardCapBCY ? 
                             totalContributionsBCY : hardCapBCY;

        // Lock the exchange rates between the accepted currencies and BCY
        _lockExchangeRates();

        // find out the token price 
        // @TODO include Presale in this
        SRC20tokenPriceBCY = SRC20tokenPriceBCY > 0 ? SRC20tokenPriceBCY : fundraiseAmountBCY / SRC20tokenSupply;

        isFinished = true;
        return true;
    }

    function setContributionRules(address rules) external returns (bool) {
        require(contributionRules != address(0), "Contribution rules already set");

        contributionRules = rules;
        return true;
    }

    function setContributorRestrictions(address restrictions) external returns (bool) {
        require(contributorRestrictions != address(0), "Contributor restrictions already set");

        contributorRestrictions = restrictions;
        return true;
    }

    function acceptContributor(address contributor) external ongoing onlyContributorRestrictions returns (bool) {
        _acceptContributor(contributor);
        return true;
    }

    function _acceptContributor(address contributor) internal returns (bool) {
        // Check whether the contributor is restricted
        require(IContributorRestrictions(contributorRestrictions).isAllowed(contributor));

        // get the value in BCY of his buffered contributions
        uint256 bufferedContributionsBCY = getBufferedContributionsBCY(contributor);

        // if we are still below the minimum, return
        if (bufferedContributionsBCY < minAmountBCY)
            return true;

        // process all the buffers
        _addContribution(contributor, zeroAddr, bufferedContributions[contributor][zeroAddr]);
        _addContribution(contributor, erc20DAI, bufferedContributions[contributor][erc20DAI]);
        _addContribution(contributor, erc20USDC, bufferedContributions[contributor][erc20USDC]);
        _addContribution(contributor, erc20WBTC, bufferedContributions[contributor][erc20WBTC]);

        emit ContributorAccepted(contributor);
        return true;
    }

    function removeContributor(address contributor) external ongoing onlyContributorRestrictions returns (bool) {
        _removeContributor(contributor);
        return true;
    }

    function _removeContributor(address contributor) internal returns (bool) {
        // make sure he is not on whitelist, if he is he can't be rejected
        require(!IContributorRestrictions(contributorRestrictions).isAllowed(contributor));

        // remove his contributions from the queue
        delete( contributionsList[msg.sender] );

        // remove all his qualified contributions back into the buffers
        // NOTE: we could set the qualified contributions to 0, but no need because of the step above
        // @TODO: actually, we can't do this because of .Offchain contributions...
        bufferedContributions[contributor][zeroAddr] += qualifiedContributions[contributor][zeroAddr];
        bufferedContributions[contributor][erc20DAI] += qualifiedContributions[contributor][erc20DAI];
        bufferedContributions[contributor][erc20USDC] += qualifiedContributions[contributor][erc20USDC];
        bufferedContributions[contributor][erc20WBTC] += qualifiedContributions[contributor][erc20WBTC];

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

    // helper function for getHistoricalBalance()
    function _getLower(uint256 val1, uint256 val2, uint256 target) internal pure returns (uint256) {
        return val1; // valjda je ovo ok....
    }

    // return the balance in _currency at the time of the _sequence
    function getHistoricalBalance(uint256 _sequence, address _currency) public view returns (uint256) {
        bal[] memory arr = historicalBalance[_currency];
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

    // @TODO make this function restartable
    // Returns 0 if all tokens have been claimed, an integer if more are left
    function claimTokens() external returns (uint256) {

        require(isFinished);

        // go through a contributor's contributions, sum up those qualified for
        // converting into tokens

        uint256 totalContributorAcceptedBCY = 0;

        for (uint256 i=0; i<contributionsList[msg.sender].length; i++) {

            // to make sure we pay him out only once
            if (contributionsList[msg.sender][i].status != ContributionStatus.Refundable)
                continue;

            // we change to accepted... but could also be deleting
            contributionsList[msg.sender][i].status = ContributionStatus.Accepted;

            uint256 contributionBCY = toBCY(contributionsList[msg.sender][i].amount,
                                            contributionsList[msg.sender][i].currency);

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

    // process a withdrawal by the Issuer, making sure not more than the correct
    // amount is taken
    function processIssuerWithdrawal(address currency) internal returns (bool) {
        
        uint256 amount = qualifiedSums[currency];
        uint256 amountBCY = toBCY(qualifiedSums[currency], currency);
        if (totalIssuerWithdrawalsBCY + amountBCY > fundraiseAmountBCY) {
            amount = qualifiedSums[currency] *
                     (fundraiseAmountBCY - totalIssuerWithdrawalsBCY) / amountBCY;
            amountBCY = toBCY(amount, currency);
        }

        qualifiedSums[currency] -= amount;
        totalIssuerWithdrawalsBCY += amountBCY;

        if (currency == zeroAddr)
            issuerWallet.transfer(amount);
        else
            IERC20(currency).transfer(issuerWallet, amount);

        emit IssuerWithdrawal(issuerWallet, currency, amount);
        return true;
    }

    // Call this function when you want to StakeAndMint without IssuerStakeOfferPool
    // Note that this function assumes that the Token Issuer has acquired SWM by
    // some other means and put them on the account of the Fundraise contract... it 
    // does not facilitate him using fundraise proceeds to get SWM
    // @TODO think more about this flow...
    function stakeAndMint() public returns (bool) {


        uint256 numSRC20Tokens = SRC20tokenSupply > 0 ? SRC20tokenSupply : fundraiseAmountBCY / SRC20tokenPriceBCY;
        // Stake and mint
        //@TODO IMinter
        IGetRateMinter(minter).stakeAndMint(src20, numSRC20Tokens);

        finishFundraise();
        require(isFinished);

        // Withdraw the ETH and the Tokens
        // @TODO one function
        processIssuerWithdrawal(zeroAddr);
        processIssuerWithdrawal(erc20DAI);
        processIssuerWithdrawal(erc20USDC);
        processIssuerWithdrawal(erc20WBTC);



        return true;
    }

    // call this function when you want to use ISOP and let it choose providers
    function stakeAndMint(address ISOP, uint256 maxMarkup) external returns (bool) {
        // we just create an empty list and call the worker function with that
        address[] memory a;
        stakeAndMint(ISOP, a, maxMarkup);
        return true;
    }

    // call this function when you want to use ISOP with specific providers
    function stakeAndMint(address ISOP, address[] memory addressList, uint256 maxMarkup) public returns (bool) {
        // This has all the conditions and will blow up if they are not met
        // @TODO move below stakeAndMint
        finishFundraise();
        require(isFinished);

        // @TODO Update the NAV
        // assetRegistry.updateNetAssetValueUSD(src20, netAssetValueUSD);
        uint256 netAssetValueUSD = toUSD(fundraiseAmountBCY);
        uint256 swmAmount = IGetRateMinter(minter).calcStake(netAssetValueUSD);

        // If we passed an empty array, that is, if we want to use the providers in the 
        // order they registered to ISOP

        uint256 spentETH;
        uint256 priceETH;
        if (addressList.length == 0) {
            priceETH = IIssuerStakeOfferPool(ISOP).loopGetSWMPriceETH(swmAmount, maxMarkup);
            IIssuerStakeOfferPool(ISOP).loopBuySWMTokens.value(priceETH)(swmAmount, maxMarkup);
            // @TODO accept all currencies
        }
        else { // loop through the list we got
           for (uint256 i = 0; i < addressList.length; i++) {
                 address swmProvider = addressList[i];

                // @TODO add other currencies
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
        qualifiedSums[zeroAddr] -= spentETH; priceETH;

        // SWM are on the Fundraise contract, approve the minter to spend them

        // this needs to be called by ISOP, because ISOP is owner of the tokens
        IERC20(SwarmERC20).approve(minter, swmAmount);

        uint256 numSRC20Tokens = SRC20tokenSupply > 0 ? SRC20tokenSupply : fundraiseAmountBCY / SRC20tokenPriceBCY;
        // Stake and mint
        IGetRateMinter(minter).stakeAndMint(src20, numSRC20Tokens);

        // Withdraw the ETH and the Tokens
        processIssuerWithdrawal(zeroAddr);
        processIssuerWithdrawal(erc20DAI);
        processIssuerWithdrawal(erc20USDC);
        processIssuerWithdrawal(erc20WBTC);

        return true;
    }

    // convert from base currency to USD
    function toUSD(uint256 amountBCY) public returns (uint256) {

        if (baseCurrency == erc20USDC || baseCurrency == erc20DAI)
            return amountBCY;

        if (baseCurrency == zeroAddr)
            return IUniswap(exchange[erc20USDC]).getEthToTokenInputPrice(amountBCY);

        // if (baseCurrency == erc20WBTC) 
        uint256 amountETH = IUniswap(exchange[erc20WBTC]).getTokenToEthInputPrice(amountBCY);
        return IUniswap(exchange[erc20USDC]).getEthToTokenInputPrice(amountETH);
    }

    // Convert an amount in currency into an amount in base currency
    function toBCY(uint256 amount, address currency) public returns (uint256) {

        // return locked rates if the Fundraise finished
        if(isFinished)
            return lockedExchangeRate[currency] * amount;

        uint256 amountETH;
        uint256 amountBCY;

        // If same, just return the input
        if (currency == baseCurrency)
            return amount;

        // ERC20 - ETH
        if (baseCurrency == zeroAddr) {
            amountBCY = IUniswap(exchange[currency]).getTokenToEthInputPrice(amount);
            return amountBCY;
        }

        // ETH - ERC20
        if (currency == zeroAddr) {
            amountBCY = IUniswap(exchange[baseCurrency]).getEthToTokenInputPrice(amount);
            return amountBCY;
        }

        // ERC20 - ERC20
        amountETH = IUniswap(exchange[currency]).getTokenToEthInputPrice(amount);
        amountBCY = IUniswap(exchange[baseCurrency]).getEthToTokenInputPrice(amountETH);
        return amountBCY;

        // @TODO investigate how this works...
        // if (currency == zeroAddr) {
        //     return amount.mul(10 ** 18).div(rateETHtoBCY);
        // } else if (currency == erc20DAI) {
        //     return amount.mul(10 ** 18).div(rateDAItoBCY);
        // } else if (currency == erc20USDC) {
        //     return amount.mul(10 ** 18).div(rateUSDCtoBCY);
        // } else {
        //     return amount.mul(10 ** 18).div(rateWBTCtoBCY);
        // }
    }

}
