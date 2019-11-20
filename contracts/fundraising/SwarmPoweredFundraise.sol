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

    event Contribution(address indexed from, uint256 amount, uint256 sequence, address baseCurrency);

    // Setup variables that never change
    string public label;
    address public src20;
    uint256 public tokenAmount;
    uint256 public startDate;
    uint256 public endDate;
    uint256 public softCapBCY;
    uint256 public hardCapBCY;
    address public baseCurrency;

    uint256 public expirationTime = 7776000; // 60 * 60 * 24 * 90 = ~3months

    bool public contributionLocking = true;

    uint256 public minAmountBCY;
    uint256 public maxAmountBCY;
    uint256 public tokenPriceBCY;
    uint256 public totalTokenAmount;
    uint256 public fundraiseAmountBCY;


    // @TODO pass these as parameters
    // @TODO mapping(uint256 => address) erc20;
    address zeroAddr = address(0); // 0x0000000000000000000000000000000000000000; // Stands for ETH
    address erc20DAI = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address erc20USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address erc20WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    // IAccCurrency - address accCurrency;

    // An Uniswap exchange for each currency
    mapping(address => address) exchange;

    // @TODO abstract away conversions and exchanges to an interface
    // NOTE: bonding curves are not the same as deep markets where any amount barely moves the price

    address SwarmERC20;
    address minter;
    address payable issuerWallet;

    // State variables that change over time
    enum ContributionStatus { Refundable, Refunded, Accepted, Offchain }
    struct contribution {
        address currency;
        uint256 amount;
        uint256 sequence;
        ContributionStatus status;
    }

    // @TODO maybe rename to contributionsQueue?
    mapping(address => contribution[]) contributionsList; 

    // @TODO think about pending vs buffered
    mapping(address => mapping(address => uint256)) bufferedContributions;

    mapping(address => mapping(address => uint256)) qualifiedContributions;

    mapping(address => uint256) qualifiedSums;

    mapping(address => uint256) lockedExchangeRate;

    uint256 public sequence;

    bool public isFinished;

    address public contributionRules;
    address public contributorRestrictions;

    modifier onlyContributorRestrictions() {
        require(msg.sender == contributorRestrictions);
        _;
    }

    // @TODO only allow the 4 currencies we accept, otherwise we have a mess downstream
    modifier onlyAcceptedTokens(address erc20) {
        require(erc20 == zeroAddr ||
                erc20 == erc20DAI ||
                erc20 == erc20USDC ||
                erc20 == erc20WBTC, 
                'Unsupported currency');
        _;
    }

    // @TODO maybe simplify like this
    struct CurrencyStats {
        address exchangeContract;
        uint256 finalExchangeRate;
        uint256 totalContributedAmount;
        uint256 totalQualifiedAmount;
    }

    mapping(address => CurrencyStats) currencyStats;

    struct bal {
        uint256 sequence;
        uint256 balance;
    }

    bal[] historicalBalanceETH;
    bal[] historicalBalanceDAI;
    bal[] historicalBalanceUSDC;
    bal[] historicalBalanceWBTC;

    mapping( address => bal[] ) historicalBalance;

    constructor(
        string memory _label,
        address _src20,
        uint256 _tokenAmount,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _softCapBCY,
        uint256 _hardCapBCY,
        address _baseCurrency
    ) public {
        label = _label;
        src20 = _src20;
        tokenAmount = _tokenAmount;
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
        require(tokenPriceBCY != 0 || totalTokenAmount != 0, "Contribution failed: token price or total token amount are not set");
        require(block.timestamp >= startDate, "Contribution failed: fundraising did not start");
        require(block.timestamp <= endDate, "Contribution failed: fundraising has ended");

        _contribute(msg.sender, zeroAddr, msg.value);
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

    function setTokenPriceBCY(uint256 _tokenPriceBCY) external returns (bool) {
        // One has to be set or the other, never both.
        require(tokenPriceBCY == 0, "Token price already set");
        require(totalTokenAmount == 0, "Total token amount already set");

        tokenPriceBCY = _tokenPriceBCY;
        return true;
    }

    function setTotalTokenAmount(uint256 _totalTokenAmount) external returns (bool) {
        require(tokenPriceBCY == 0, "Token price already set");
        require(totalTokenAmount == 0, "Total token amount already set");

        totalTokenAmount = _totalTokenAmount;
        return true;
    }

    // @TODO for the processing of buffers we can't have min/max checking in this function
    // because we step by step accept small amounts
    // maybe have another more basic function 
    // addContributionMinMax, addContribution
    function addContribution(address contributor, address erc20, uint256 amount) 
                             internal onlyAcceptedTokens(erc20) returns (bool) {

        // convert the coming contribution to BCY
        uint256 amountBCY = toBCY( amount, erc20 );

        // get the value in BCY of his previous qualified contributions
        uint256 previousContributionsBCY = toBCY( qualifiedContributions[contributor][zeroAddr], zeroAddr) +
                                           toBCY( qualifiedContributions[contributor][erc20DAI], erc20DAI) +
                                           toBCY( qualifiedContributions[contributor][erc20USDC], erc20USDC) +
                                          toBCY( qualifiedContributions[contributor][erc20WBTC], erc20WBTC);

        // get the total with this contribution
        uint256 totalContributionsBCY = previousContributionsBCY + amountBCY;

        // if we are still below the minimum, return
        //if (totalContributionsBCY < minAmountBCY)
        //    return;

        // now do the max checking... 

        // if we are above with previous amount, due to exchange rate fluctuations, return
        if (previousContributionsBCY >= maxAmountBCY)
            return true;

        uint256 qualifiedAmount;
        // if we cross the max, take only a portion of the contribution, via a percentage
        if (totalContributionsBCY > maxAmountBCY) {
            qualifiedAmount = (maxAmountBCY - previousContributionsBCY) / amountBCY
                            * amount;
        }
        else 
            qualifiedAmount = amount;
        
        // leave the extra in the buffer, get the all the rest
        bufferedContributions[contributor][erc20] -= qualifiedAmount;
        
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
    }

    // Allows Token Issuer to add a contribution to the fundraise's accounting
    // in the case he received an offchain contribution, for example
    // It still has to respect min and max amounts
    // @TODO check whether this can be done multiple times and whether the queue
    //       has to be respected in that case
    // @TODO check whether it is fine offchain people can get refunds at any time,
    //       while the onchain guys must wait or never get them
    // @TODO check whether it is OK to require the adding to whitelist to be a
    //       separate step
    function addOffchainContribution(address contributor, address erc20, uint256 amount) 
             public onlyAcceptedTokens(erc20) returns (bool) {

        // Check if contributor on whitelist
        if (IContributorRestrictions(contributorRestrictions).checkContributor(contributor) == false)
            return true;

        uint256 amountBCY = toBCY(amount, erc20);

        require(amountBCY > minAmountBCY, 'Contribution failed: amount less than minAmount!');
        require(IERC20(erc20).transferFrom(contributor, address(this), amount), 
            'Contribution failed: ERC20 transfer failed!');
        
        // add the contribution to the queue
        addContribution(contributor, erc20, amount);
        
        // set up the contribution we have just added so that it can not be withdrawn
        contributionsList[msg.sender][contributionsList[msg.sender].length - 1]
                         .status = ContributionStatus.Offchain;
    }

    // @TODO forceRemoveContribution
    // The way this would work is with calling _rejectContributor

    // @TODO contribute with affiliate links
    function contribute(address erc20, uint256 amount) public onlyAcceptedTokens(erc20) returns (bool) {
        _contribute(msg.sender, erc20, amount);
    }

    // Allows contributor to contribute in the form of ERC20 tokens accepted by the fundraise
    function _contribute(address contributor, address erc20, uint256 amount) 
        public onlyAcceptedTokens(erc20) returns (bool) {
        require(isFinished == false, 'Contribution failes: fundraise has completed');
        require((tokenPriceBCY != 0 || totalTokenAmount != 0), "Contribution failed: token price or total token amount are not set");
        require(block.timestamp >= startDate, "Contribution failed: fundraising did not start");
        require(block.timestamp <= endDate, "Contribution failed: fundraising has ended");
        
        require(IERC20(erc20).transferFrom(contributor, address(this), amount), 'Contribution failed: ERC20 transfer failed!');

        // add the contribution to the buffer
        bufferedContributions[contributor][erc20] += amount;

        // Check if contributor on whitelist
        if (IContributorRestrictions(contributorRestrictions).checkContributor(contributor) == false)
            return true;

        // If he already has some qualified contributions, just process the new one
        if (contributionsList[contributor].length > 0) {
            addContribution(contributor, erc20, amount);
            return true;
        }

        // If he never had qualified contributions before, see if he now has passed the minAmountBCY
        // And if so add his buffered contributions to qualified contributions

        // get the value in BCY of his buffered contributions
        uint256 totalBufferedBCY = toBCY( bufferedContributions[contributor][zeroAddr], zeroAddr) +
                                   toBCY( bufferedContributions[contributor][erc20DAI], erc20DAI) +
                                   toBCY( bufferedContributions[contributor][erc20USDC], erc20USDC) +
                                   toBCY( bufferedContributions[contributor][erc20WBTC], erc20WBTC);

        // if we are still below the minimum, return
        if (totalBufferedBCY < minAmountBCY)
            return true;

        // process all the buffers
        addContribution(contributor, zeroAddr, bufferedContributions[contributor][zeroAddr]);
        addContribution(contributor, erc20DAI, bufferedContributions[contributor][erc20DAI]);
        addContribution(contributor, erc20USDC, bufferedContributions[contributor][erc20USDC]);
        addContribution(contributor, erc20WBTC, bufferedContributions[contributor][erc20WBTC]);

        return true;
    } // fn

    // Allows contributor to withdraw all his ETH, if this is permitted by the state of the Fundraise
    function withdrawContributionETH() external returns (bool) {
        require(isFinished == true && block.timestamp < endDate.add(expirationTime), 'Withdrawal failed: fundraise has not finished');

        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            if (contributionsList[msg.sender][i].currency != address(0))
                continue;
            if (contributionsList[msg.sender][i].status != ContributionStatus.Refundable)
                continue; 
            msg.sender.transfer(contributionsList[msg.sender][i].amount);
            
            contributionsList[msg.sender][i].status = ContributionStatus.Refunded;
        }

        delete contributionsList[msg.sender];

        // withdraw from the buffer too
        msg.sender.transfer(bufferedContributions[msg.sender][zeroAddr]);
        bufferedContributions[msg.sender][zeroAddr] = 0;

        return true;
    }

    // Allows contributor to withdraw all his ETH, if this is permitted by the state of the Fundraise
    // @TODO only allow withdrawing of the amounts we didn't accept
    function withdrawContributionToken() external returns (bool) {
        require(isFinished == true && block.timestamp < endDate.add(expirationTime), 'Withdrawal failed: fundraise has not finished');

        for (uint256 i = 0; i < contributionsList[msg.sender].length; i++) {
            if (contributionsList[msg.sender][i].currency == address(0))
                continue;
            if (contributionsList[msg.sender][i].status != ContributionStatus.Refundable)
                continue; 
            // Transfer from
            require(IERC20(contributionsList[msg.sender][i].currency).transferFrom(
                    address(this),
                    msg.sender,
                    contributionsList[msg.sender][i].amount),
                'ERC20 transfer failed!');
            
            contributionsList[msg.sender][i].status = ContributionStatus.Refunded;

        }

        delete contributionsList[msg.sender];

        // withdraw from the buffers too
        if (bufferedContributions[msg.sender][erc20DAI] > 0)
            require(IERC20(erc20DAI).transferFrom(address(this),msg.sender,bufferedContributions[msg.sender][erc20DAI]),
                    'ERC20 transfer failed!');
        bufferedContributions[msg.sender][erc20DAI] = 0;

        if (bufferedContributions[msg.sender][erc20USDC] > 0)
            require(IERC20(erc20USDC).transferFrom(address(this),msg.sender,bufferedContributions[msg.sender][erc20USDC]),
                    'ERC20 transfer failed!');
        bufferedContributions[msg.sender][erc20USDC] = 0;

        if (bufferedContributions[msg.sender][erc20WBTC] > 0)
            require(IERC20(erc20WBTC).transferFrom(address(this),msg.sender,bufferedContributions[msg.sender][erc20WBTC]),
                    'ERC20 transfer failed!');
        bufferedContributions[msg.sender][erc20WBTC] = 0;

        return true;
    }

    function allowContributionWithdrawals() external returns (bool) {
        delete contributionLocking;
        return true;
    }

    function getPresale() external pure returns (uint256, uint256) {
        return (0, 0);
    }

    // Perform all the necessary actions to finish the fundraise
    function finishFundraising() internal returns (bool) {
        require(isFinished == false, "Failed to finish fundraising: Fundraising already finished");
        require(block.timestamp < endDate.add(expirationTime), "Failed to finish fundraising: expiration time passed");

        uint256 totalContributionsBCY = toBCY(qualifiedSums[zeroAddr], zeroAddr) +
                                        toBCY(qualifiedSums[erc20DAI], erc20DAI) +
                                        toBCY(qualifiedSums[erc20USDC], erc20USDC) +
                                        toBCY(qualifiedSums[erc20WBTC], erc20WBTC);

        require(totalContributionsBCY >= softCapBCY, "Failed to finish: SoftCap not reached");

        // lock the fundraise amount... it will be somewhere between the soft and hard caps
        fundraiseAmountBCY = totalContributionsBCY < hardCapBCY ? 
                             totalContributionsBCY : hardCapBCY;

        // @TODO check with business if this logic is acceptable
        lockedExchangeRate[zeroAddr] = toBCY( 1, zeroAddr );
        lockedExchangeRate[erc20DAI] = toBCY( 1, erc20DAI );
        lockedExchangeRate[erc20USDC] = toBCY( 1, erc20USDC );
        lockedExchangeRate[erc20WBTC] = toBCY( 1, erc20WBTC );

        // @TODO fix token price

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

    function acceptContributor(address contributor) external onlyContributorRestrictions returns (bool) {
        _acceptContributor(contributor);
        return true;
    }

    function rejectContributor(address contributor) external onlyContributorRestrictions returns (bool) {
        _rejectContributor(contributor);
        return true;
    }

    function _acceptContributor(address contributor) internal returns (bool) {
        // Check if contributor on whitelist
        require(IContributorRestrictions(contributorRestrictions).checkContributor(contributor));
        //  @TODO change name to: isRestricted // isAllowed //isPermitted // 
        //                        isVerified // checksOut // contributorAllowed // contributionAllowed

        // get the value in BCY of his buffered contributions
        uint256 totalBufferedBCY = toBCY( bufferedContributions[contributor][zeroAddr], zeroAddr) +
                                   toBCY( bufferedContributions[contributor][erc20DAI], erc20DAI) +
                                   toBCY( bufferedContributions[contributor][erc20USDC], erc20USDC) +
                                   toBCY( bufferedContributions[contributor][erc20WBTC], erc20WBTC);

        // if we are still below the minimum, return
        if (totalBufferedBCY < minAmountBCY)
            return true;

        // process all the buffers
        addContribution(contributor, zeroAddr, bufferedContributions[contributor][zeroAddr]);
        addContribution(contributor, erc20DAI, bufferedContributions[contributor][erc20DAI]);
        addContribution(contributor, erc20USDC, bufferedContributions[contributor][erc20USDC]);
        addContribution(contributor, erc20WBTC, bufferedContributions[contributor][erc20WBTC]);
        
        return true;
    }

    // @TODO check with business... can Token Issuer do this even after the fundraise is Finished?
    //       probably not, eh?
    function _rejectContributor(address contributor) internal returns (bool) {
        // make sure he is not on whitelist, if he is he can't be rejected
        require(!IContributorRestrictions(contributorRestrictions).checkContributor(contributor));

        // remove his contributions from the queue
        delete( contributionsList[msg.sender] );

        // remove all his qualified contributions back into the buffers
        // NOTE: we could set the qualified contributions to 0, but no need because of the step above
        bufferedContributions[contributor][zeroAddr] += qualifiedContributions[contributor][zeroAddr];
        bufferedContributions[contributor][erc20DAI] += qualifiedContributions[contributor][erc20DAI];
        bufferedContributions[contributor][erc20USDC] += qualifiedContributions[contributor][erc20USDC];
        bufferedContributions[contributor][erc20WBTC] += qualifiedContributions[contributor][erc20WBTC];

        // adjust the global sums
        // NOTE: we'll actually leave global sums as they are, as they need to stay the same for historical
        // balances to work

        // get the value in BCY of his previous qualified contributions
        uint256 contributionsBCY = toBCY( qualifiedContributions[contributor][zeroAddr], zeroAddr) +
                                   toBCY( qualifiedContributions[contributor][erc20DAI], erc20DAI) +
                                   toBCY( qualifiedContributions[contributor][erc20USDC], erc20USDC) +
                                   toBCY( qualifiedContributions[contributor][erc20WBTC], erc20WBTC);

        // adjust the caps, which are always in BCY
        softCapBCY = softCapBCY + contributionsBCY;
        hardCapBCY = hardCapBCY + contributionsBCY;

        return true;
    }

    // helper function for getHistoricalBalance()
    function _getLower(uint256 val1, uint256 val2, uint256 target) internal pure returns (uint256) {
        return val1; // valjda je ovo ok....
    }

    // return the balance at the time of the sequence passed as parameter
    function getHistoricalBalance(uint256 _sequence, address _currency) public view returns (uint256) {
        bal[] memory arr;
        if (_currency == zeroAddr) {
            arr = historicalBalanceETH;
        } else if (_currency == erc20DAI) {
            arr = historicalBalanceDAI;
        } else if (_currency == erc20USDC) {
            arr = historicalBalanceUSDC;
        } else if (_currency == erc20WBTC) {
            arr = historicalBalanceWBTC;
        }
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

            contributionsList[msg.sender][i].status = ContributionStatus.Accepted;

            uint256 historicalBalanceBCY = 
                toBCY( getHistoricalBalance(i, zeroAddr), zeroAddr) + 
                toBCY( getHistoricalBalance(i, erc20DAI), erc20DAI) + 
                toBCY( getHistoricalBalance(i, erc20USDC), erc20USDC) + 
                toBCY( getHistoricalBalance(i, erc20WBTC), erc20WBTC);

            uint256 contributionBCY = toBCY(contributionsList[msg.sender][i].amount,
                                            contributionsList[msg.sender][i].currency);

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

        // find out the token price @TODO, this is global, remove from function and put
        // into StakeAndMint or finishFundraise
        // @TODO include Presale in this
        
        tokenPriceBCY = tokenPriceBCY > 0 ? tokenPriceBCY : totalContributorAcceptedBCY / totalTokenAmount;
        
        uint256 tokenAllotment = totalContributorAcceptedBCY / tokenPriceBCY;
        ISRC20(src20).transfer(msg.sender, tokenAllotment);
        return 0;
    }

    // call this function when you want to use isop
    function stakeAndMint(address ISOP) external returns (bool) {
        address[] memory a;
        stakeAndMint(ISOP, a);

        return true;
    }

    // @TODO add missing function for calling Stake and Mint with own tokens

    // call this function when you want to use ISOP with specific providers
    function stakeAndMint(address ISOP, address[] memory addressList) public returns (bool) {
        require(isFinished);

        // Mint
        uint256 totalContributionsBCY = toBCY(qualifiedSums[zeroAddr], zeroAddr) +
                                        toBCY(qualifiedSums[erc20DAI], erc20DAI) +
                                        toBCY(qualifiedSums[erc20USDC], erc20USDC) +
                                        toBCY(qualifiedSums[erc20WBTC], erc20WBTC);

        // This has all the conditions and will blow up if they are not met
        finishFundraising();

        // @TODO convert all to SafeMath when happy with logic
        // @TODO Update the NAV
        // assetRegistry.updateNetAssetValueUSD(src20, netAssetValueUSD);
        uint256 netAssetValueUSD = toUSD(fundraiseAmountBCY);
        uint256 swmAmount = IGetRateMinter(minter).calcStake(netAssetValueUSD);

        // Collect the SWM tokens from ISOP. For now we don't loop but only have
        // One provider, chosen by the Token Issuer
        // @TODO loop through providers
        address swmProvider = addressList[0];
        uint256 priceETH = IIssuerStakeOfferPool(ISOP).getSWMPriceETH(swmProvider, swmAmount);
        IIssuerStakeOfferPool(ISOP).buySWMTokens.value(priceETH)(swmProvider, swmAmount);

        // SWM are on the Fundraise contract, approve the minter to spend them

        // this needs to be called by ISOP, because ISOP is owner of the tokens
        IERC20(SwarmERC20).approve(minter, swmAmount);

        uint256 numSRC20Tokens = totalTokenAmount > 0 ? totalTokenAmount : totalContributionsBCY / tokenPriceBCY;
        IGetRateMinter(minter).stakeAndMint(src20, numSRC20Tokens);

        // Withdraw
        // Withdraw accepted ETH, minus the amount spent to buy SWM tokens
        issuerWallet.transfer(qualifiedSums[zeroAddr] - priceETH);

        // Withdraw accepted DAI
        IERC20(erc20DAI).transfer(issuerWallet, qualifiedSums[erc20DAI]);

        // Withdraw accepted USDC
        IERC20(erc20USDC).transfer(issuerWallet, qualifiedSums[erc20USDC]);

        // Withdraw accepted WBTC
        IERC20(erc20WBTC).transfer(issuerWallet, qualifiedSums[erc20WBTC]);

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

        // @TODO return locked rates if the Fundraise finished
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

    }

    // @TODO stakeAndMint without IssuerStakeOfferPool
}